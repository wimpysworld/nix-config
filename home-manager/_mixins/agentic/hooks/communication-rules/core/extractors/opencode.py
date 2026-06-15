"""OpenCode event extraction for the Communication Rules core.

Lifted from the embedded Python in ``adapters/opencode.sh`` (the
``opencode_extract_payload`` heredoc and the shell dispatch modes). The body
extraction is unchanged in substance: the string helpers, the first-string and
collect-strings helpers, the tool-name and arguments readers, the event-name
reader, the name normaliser, the command-from-args helper, the tool-kind checks,
the post-tool check, the patch-added-text helper, the tool extractor, and the
display-surface and display extractor all behave as before. The change is the
seam: instead of writing an action word and a value to two temp files, this
module returns the normalised ``Extraction`` the dispatcher's shared middle
consumes. The write-result helper is dropped.

The surface decision (local B1 versus external B2) and the operator target move
here from the old OpenCode TypeScript plugin (``isExternalSurface``,
``externalTarget``, ``localTarget``). The core picks the limit and key namespace
from the surface; this module only classifies it.

Two behaviour points the proposal pins down:

- Bash tool calls (and gh / gh-api-safe post commands) put the command text into
  the record's ``texts`` and route through ``scan_bash`` (``scan_mode = bash``),
  NOT through any baked bash detection. The SURFACE choice uses the external
  check below; the BODY detection is ``scan_bash``.
- The post-detection lists (post text keys, post tool terms, external target
  keys) are read from ``core.config``, not baked here. There is no fallback copy
  in this module.

A Tier A extraction failure (a displayed final or subagent message with an
unresolvable body) must RE-ISSUE, not block. The display surfaces map to the
``facing`` event class; an unresolvable scan there flows through the state
machine's fail-open-to-reissue path, mirroring the Pi and Codex extractors.

``turn`` is always ``None`` for OpenCode: its events carry no turn id, so the
strike counter is keyed on session, tool, and a stable target. The session id
is passed straight through; the non-empty session guarantee is enforced in
``core.state``.
"""

from __future__ import annotations

from typing import Any

from core.config import Config
from core.detection import (
    bash_prose_sink,
    parse_command_line,
    patch_added_text,
    shell_c_inner_script,
    strip_env_assignments,
)
from core.dispatch import (
    EVENT_CONTEXT,
    EVENT_FACING,
    EVENT_GATE,
    EVENT_PASS,
    SCAN_BASH,
    SCAN_NONE,
    SCAN_TEXT,
    Extraction,
)
from core.types import ExtractorRecord


# Body-bearing field names by tool kind, lifted verbatim from the opencode.sh
# embedded Python. The first matching key wins.
WRITE_FIELDS = ("content", "text", "body", "value", "newContent", "fileContent")
EDIT_FIELDS = ("newString", "new_string", "replacement", "content", "text")
PATCH_FIELDS = ("patch", "patchText", "diff", "content", "text")
BASH_FIELDS = ("command", "cmd", "script", "bash")
POST_FIELDS = ("body", "comment", "message", "note", "notes", "text", "title")
DISPLAY_FIELDS = ("content", "message", "text", "output", "final", "response")

# File tools whose stable B1 target is the file path: the local strike counter
# keys on the path, so a model that revises the body between retries still walks
# the cap. Mirrors the old OpenCode plugin's localTarget set.
_FILE_TOOL_NAMES = {
    "write",
    "edit",
    "multiedit",
    "multi_edit",
    "patch",
    "apply_patch",
    "str_replace",
}

_FILE_TARGET_KEYS = ("path", "file_path", "filePath", "filename", "file")


def strings(value: Any) -> list[str]:
    output: list[str] = []
    if isinstance(value, str):
        if value:
            output.append(value)
    elif isinstance(value, list):
        for item in value:
            output.extend(strings(item))
    elif isinstance(value, dict):
        for item in value.values():
            output.extend(strings(item))
    return output


def first_string(data: Any, keys: tuple[str, ...]) -> str | None:
    if not isinstance(data, dict):
        return None
    for key in keys:
        value = data.get(key)
        if isinstance(value, str) and value:
            return value
    for value in data.values():
        if isinstance(value, dict):
            found = first_string(value, keys)
            if found:
                return found
    return None


def collect_strings(data: Any, keys: tuple[str, ...]) -> list[str]:
    found: list[str] = []
    if isinstance(data, dict):
        for key, value in data.items():
            if key in keys:
                found.extend(strings(value))
            elif isinstance(value, (dict, list)):
                found.extend(collect_strings(value, keys))
    elif isinstance(data, list):
        for item in data:
            found.extend(collect_strings(item, keys))
    return found


def tool_name(data: Any) -> str:
    candidates = []
    if isinstance(data, dict):
        candidates.extend(
            [
                data.get("tool"),
                data.get("toolName"),
                data.get("tool_name"),
                data.get("name"),
                data.get("id"),
            ]
        )
        tool = data.get("tool")
        if isinstance(tool, dict):
            candidates.extend([tool.get("name"), tool.get("id")])
        call = data.get("call")
        if isinstance(call, dict):
            candidates.extend([call.get("name"), call.get("tool"), call.get("id")])
    for candidate in candidates:
        if isinstance(candidate, str) and candidate:
            return candidate
    return ""


def arguments(data: Any) -> Any:
    if not isinstance(data, dict):
        return {}
    for key in ("args", "arguments", "input", "parameters"):
        value = data.get(key)
        if isinstance(value, (dict, list, str)):
            return value
    tool = data.get("tool")
    if isinstance(tool, dict):
        for key in ("args", "arguments", "input", "parameters"):
            value = tool.get(key)
            if isinstance(value, (dict, list, str)):
                return value
    call = data.get("call")
    if isinstance(call, dict):
        for key in ("args", "arguments", "input", "parameters"):
            value = call.get(key)
            if isinstance(value, (dict, list, str)):
                return value
    return {}


def event_name(data: Any) -> str:
    if not isinstance(data, dict):
        return ""
    for key in ("event", "hook", "type"):
        value = data.get(key)
        if isinstance(value, str):
            return value
    return ""


def normalise_name(name: str) -> str:
    return name.lower().replace("-", "_").replace(".", "_")


def command_from_args(args: Any) -> str | None:
    if isinstance(args, str) and args:
        return args
    if isinstance(args, list) and args:
        return " ".join(str(item) for item in args)
    if isinstance(args, dict):
        command = first_string(args, BASH_FIELDS)
        if command:
            return command
        argv = args.get("argv") or args.get("args")
        if isinstance(argv, list) and argv:
            return " ".join(str(item) for item in argv)
    return None


def is_write_tool(name: str) -> bool:
    normalised = normalise_name(name)
    return normalised in {"write", "file_write", "write_file"} or normalised.endswith("_write")


def is_edit_tool(name: str) -> bool:
    normalised = normalise_name(name)
    return normalised in {"edit", "multiedit", "multi_edit", "str_replace"} or normalised.endswith("_edit")


def is_patch_tool(name: str) -> bool:
    normalised = normalise_name(name)
    return normalised in {"patch", "apply_patch"} or normalised.endswith("_patch")


def is_bash_tool(name: str) -> bool:
    normalised = normalise_name(name)
    return normalised in {"bash", "shell", "run_command", "execute_command"}


def is_post_capable_mcp_tool(name: str, post_tool_terms: tuple[str, ...]) -> bool:
    if not name.startswith("mcp__"):
        return False
    leaf = name.rsplit("__", 1)[-1].lower()
    return any(term in leaf for term in post_tool_terms)


def is_post_tool(name: str, args: Any) -> bool:
    normalised = normalise_name(name)
    if normalised in {"gh", "gh_api_safe", "github"}:
        return True
    command = command_from_args(args)
    if command:
        stripped = command.strip()
        return stripped.startswith("gh ") or stripped.startswith("gh-api-safe ")
    if isinstance(args, dict):
        return any(key in args for key in POST_FIELDS)
    return False


def display_surface(data: Any) -> bool:
    if not isinstance(data, dict):
        return False
    event = event_name(data)
    if event in {"message.final", "message.end", "subagent.final", "subagent.end"}:
        return True
    surface = data.get("surface") or data.get("messageType") or data.get("kind")
    return surface in {"final", "subagent"}


def _event_properties(data: Any) -> dict | None:
    if not isinstance(data, dict):
        return None
    event = data.get("event")
    if isinstance(event, dict) and isinstance(event.get("properties"), dict):
        return event["properties"]
    if isinstance(data.get("properties"), dict):
        return data["properties"]
    return None


def completed_subagent_text(data: Any) -> str | None:
    # Lifted from the old OpenCode plugin's completedSubagentOutput: detect a
    # finished subagent tool part in a raw ``message.part.updated`` event and
    # return its displayed text. Event-shape extraction, not policy. The shim
    # passes the raw event through as ``opencode event`` so this lives in the
    # core, mirroring how the Pi extractor parses its raw events.
    if event_name(data) != "message.part.updated":
        return None
    properties = _event_properties(data)
    part = properties.get("part") if isinstance(properties, dict) else None
    if not isinstance(part, dict):
        return None
    if part.get("type") != "tool":
        return None
    tool = part.get("tool") if isinstance(part.get("tool"), str) else part.get("name")
    if tool not in {"task", "agent", "subagent"}:
        return None
    state = part.get("state")
    if not isinstance(state, dict) or state.get("status") != "completed":
        return None
    output = state.get("output")
    if isinstance(output, str) and output:
        return output
    if isinstance(output, dict):
        return first_string(output, ("text", "output", "content"))
    return None


def is_external_surface(name: str, args: Any, config: Config) -> bool:
    # External (B2) surface: the gh CLI tools, a post-capable MCP tool, or a bare
    # "gh "/"gh-api-safe " command. Everything else is local (B1). Mirrors the old
    # OpenCode plugin's isExternalSurface. SURFACE-CHOICE signal only; the command
    # body is scanned by scan_bash.
    normalised = name.lower()
    if normalised in {"gh", "gh-api-safe", "github"}:
        return True
    if is_post_capable_mcp_tool(name, config.post_tool_terms):
        return True
    command = command_from_args(args)
    if command:
        # Parse the command and strip a leading env assignment (``GH_TOKEN=x gh
        # ...``) so the gh leading-token test sees the real command. A raw-string
        # ``startswith("gh ")`` would miss the env prefix.
        argv = parse_command_line(command)
        if argv is not None:
            stripped_argv = strip_env_assignments(argv)
            if stripped_argv and stripped_argv[0] in {"gh", "gh-api-safe"}:
                return True
            # A shell ``-c`` wrapper hides the gh post inside one token, so
            # unwrap it and test the inner script's leading token too.
            inner = shell_c_inner_script(stripped_argv)
            if inner is not None:
                inner_argv = parse_command_line(inner)
                if inner_argv is not None:
                    inner_stripped = strip_env_assignments(inner_argv)
                    return bool(inner_stripped) and inner_stripped[0] in {"gh", "gh-api-safe"}
    return False


def external_target(name: str, args: Any, external_target_keys: tuple[str, ...]) -> str:
    # Operator-visible target for the B2 yield notice: prefer an explicit
    # identifier from the args, else fall back to the tool name. Mirrors the old
    # OpenCode plugin's externalTarget.
    label = name or "post"
    if isinstance(args, dict):
        for key in external_target_keys:
            value = args.get(key)
            if isinstance(value, str) and value:
                return f"{label} {value}"
            if isinstance(value, int) and not isinstance(value, bool):
                return f"{label} {value}"
    return label


def local_target(name: str, args: Any) -> str | None:
    # The STABLE B1 target the local strike counter keys on: the file path for
    # write/edit/patch tools. Returns None for bash or a pathless call, so the key
    # falls back to session+tool. Mirrors the old OpenCode plugin's localTarget.
    normalised = normalise_name(name)
    is_file_tool = (
        normalised in _FILE_TOOL_NAMES
        or normalised.endswith("_write")
        or normalised.endswith("_edit")
        or normalised.endswith("_patch")
    )
    if not is_file_tool or not isinstance(args, dict):
        return None
    for key in _FILE_TARGET_KEYS:
        value = args.get(key)
        if isinstance(value, str) and value:
            return value
    return None


def extract_tool(data: Any) -> tuple[str, str]:
    # Body extraction for tool.execute.before, lifted from the opencode.sh
    # embedded Python. Returns (action, value): "gate-text", "gate-bash",
    # "fail-closed", or "pass".
    if event_name(data) not in {"", "tool.execute.before"}:
        return "pass", ""

    name = tool_name(data)
    args = arguments(data)

    if is_write_tool(name):
        text = first_string(args, WRITE_FIELDS)
        return ("gate-text", text) if text else ("fail-closed", "")

    if is_edit_tool(name):
        texts = collect_strings(args, EDIT_FIELDS)
        return ("gate-text", "\n".join(texts)) if texts else ("fail-closed", "")

    if is_patch_tool(name):
        text = first_string(args, PATCH_FIELDS)
        if not text:
            return "fail-closed", ""
        additions = patch_added_text(text)
        return ("gate-text", additions) if additions else ("pass", "")

    if is_bash_tool(name):
        command = command_from_args(args)
        return ("gate-bash", command) if command else ("fail-closed", "")

    if is_post_tool(name, args):
        command = command_from_args(args)
        if command:
            return "gate-bash", command
        texts = collect_strings(args, POST_FIELDS)
        return ("gate-text", "\n".join(texts)) if texts else ("fail-closed", "")

    return "pass", ""


def extract_display(data: Any) -> tuple[str, str]:
    # Body extraction for a displayed final or subagent message, lifted from the
    # opencode.sh embedded Python. Returns (action, value): "correction" or
    # "pass". A surface with no resolvable text passes (no body to scan).
    if not display_surface(data):
        return "pass", ""
    texts = collect_strings(data, DISPLAY_FIELDS)
    if not texts:
        return "pass", ""
    return "correction", "\n".join(texts)


def _session(payload: dict[str, Any]) -> str:
    for key in ("session_id", "sessionID", "sessionId"):
        value = payload.get(key)
        if isinstance(value, str):
            return value
    return ""


def _pass(session: str) -> Extraction:
    return Extraction(
        record=ExtractorRecord(session=session, turn=None, tool="", target=None, texts=[]),
        event_class=EVENT_PASS,
        scan_mode=SCAN_NONE,
    )


def _extract_tool_execute_before(payload: dict[str, Any], session: str, config: Config) -> Extraction:
    action, value = extract_tool(payload)

    if action == "pass":
        return _pass(session)

    name = tool_name(payload)
    args = arguments(payload)
    is_external = is_external_surface(name, args, config)
    surface = "external" if is_external else "local"
    target = external_target(name, args, config.external_target_keys) if is_external else local_target(name, args)
    record = ExtractorRecord(session=session, turn=None, tool=name, target=target, texts=[])

    gate_args = {
        "record": record,
        "event_class": EVENT_GATE,
        "surface": surface,
    }

    # An unresolvable body fails closed on this gating surface: deny or yield
    # under the cap, never pass.
    if action == "fail-closed":
        return Extraction(scan_mode=SCAN_NONE, unresolved=True, **gate_args)

    if action == "gate-bash":
        # The command body routes through scan_bash, never through a baked bash
        # detection path. For a LOCAL Bash write the strike TARGET is the first
        # prose sink the command writes, so it keys per-file like write/edit. An
        # external gh post keeps its B2 target. No resolvable sink leaves the
        # coarse session+tool key.
        record.texts = [value]
        if not is_external:
            record.target = bash_prose_sink(value)
        return Extraction(scan_mode=SCAN_BASH, **gate_args)

    # action == "gate-text": prose tools and post bodies.
    record.texts = [value]
    return Extraction(scan_mode=SCAN_TEXT, **gate_args)


def _extract_display(payload: dict[str, Any], session: str) -> Extraction:
    record = ExtractorRecord(session=session, turn=None, tool="display", target=None, texts=[])
    facing = {"record": record, "event_class": EVENT_FACING}

    if not display_surface(payload):
        # Not a recognised display surface: nothing to scan, plain pass.
        return Extraction(scan_mode=SCAN_NONE, **facing)

    action, value = extract_display(payload)
    if action == "pass":
        # A recognised final or subagent surface whose body cannot be resolved.
        # This is a Tier A extraction failure: fail OPEN to re-issue, never hard
        # block. The state machine's facing path sets the pending-reissue flag
        # and the next turn re-issues, mirroring Pi and Codex.
        return Extraction(scan_mode=SCAN_NONE, unresolved=True, **facing)

    # action == "correction": scan the displayed prose. A breach re-issues; a
    # clean pass clears any stale flag.
    record.texts = [value]
    return Extraction(scan_mode=SCAN_TEXT, **facing)


# Display events that map onto the Tier A facing surface.
_DISPLAY_EVENTS = {
    "message.final",
    "message.end",
    "subagent.final",
    "subagent.end",
    "Stop",
    "SubagentStop",
}


def extract(event: str, payload: dict[str, Any], config: Config) -> Extraction:
    """Return the normalised Extraction for one OpenCode event.

    Maps the old shell dispatch modes onto the unified ``<event>`` extraction:

    - ``context`` / ``chat.system.transform`` -> the Tier A context build. It
      carries no body. The core reads the once-per-session base-rules dedupe and
      the pending-reissue flag from the record session and returns the injection
      flags; the shim applies them to the live ``output.system[]``. This replaces
      the old TypeScript ``injectedSystemKeys`` in-process dedupe.
    - ``tool-execute-before`` / ``tool.execute.before`` -> the Tier B gate.
    - ``post-display`` and the display events (``message.final``,
      ``subagent.final``, etc.) -> the Tier A facing surface. An unresolvable
      display body re-issues (fail-open to re-issue), never hard-blocks.

    The event name may arrive either as the dispatch mode (the old shell
    command) or as the OpenCode event in the payload, so both routes resolve to
    the same extraction.
    """
    session = _session(payload)
    payload_event = event_name(payload)

    if event in {"context", "chat.system.transform"} or payload_event == "chat.system.transform":
        record = ExtractorRecord(session=session, turn=None, tool="context", target=None, texts=[])
        return Extraction(record=record, event_class=EVENT_CONTEXT, scan_mode=SCAN_NONE)

    if event in {"tool-execute-before", "tool.execute.before"} or payload_event == "tool.execute.before":
        return _extract_tool_execute_before(payload, session, config)

    if event == "event" or payload_event == "message.part.updated":
        # A raw OpenCode event: only a finished subagent message is a Tier A
        # facing surface. Anything else passes.
        text = completed_subagent_text(payload)
        if text is None:
            return _pass(session)
        if not session:
            properties = _event_properties(payload)
            part = properties.get("part") if isinstance(properties, dict) else None
            session = first_string(part, ("sessionID", "sessionId", "session_id")) or (
                first_string(properties, ("sessionID", "sessionId", "session_id")) if properties else None
            ) or ""
        record = ExtractorRecord(session=session, turn=None, tool="display", target=None, texts=[text])
        return Extraction(record=record, event_class=EVENT_FACING, scan_mode=SCAN_TEXT)

    if event in {"post-display"} or event in _DISPLAY_EVENTS or display_surface(payload):
        return _extract_display(payload, session)

    return _pass(session)
