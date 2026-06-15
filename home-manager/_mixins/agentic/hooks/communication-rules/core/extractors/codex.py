"""Codex event extraction for the Communication Rules core.

Lifted from the embedded Python in ``adapters/codex.sh`` (the ``codex_extract``
heredoc and the heredoc dispatch modes). The extraction logic is unchanged in
substance: the payload loader, the path reader, the text helpers, the transcript
reader, the body-text collector, the mcp-tool check, the gh-post check, the
bash-command reader, the external-surface check, the post-tool check, and the
target helpers all behave as before. The change is the seam: instead of printing
a value per heredoc mode, this module returns the normalised ``Extraction`` the
dispatcher's shared middle consumes.

Two behaviour points the proposal pins down:

- Bash tool calls put the command text into the record's ``texts`` and route
  through ``scan_bash`` (``scan_mode = bash``), NOT through the gh-post body
  check. The SURFACE choice (local B1 versus external B2) still uses the
  external check below, mirroring the old adapter.
- The post-detection lists (post text keys, post tool terms, external target
  keys) are read from ``core.config``, not baked here. There is no fallback copy
  in this module.

``turn`` is set from the Codex ``turn_id``: Codex keeps its per-turn reset, so
the strike key includes the turn and a new turn id starts a fresh count. The
other three agents omit ``turn``.
"""

from __future__ import annotations

import json
import os
from typing import Any

from core.config import Config
from core.detection import (
    apply_patch_target,
    bash_prose_sink,
    parse_command_line,
    read_text_file,
    shell_c_inner_script,
)
from core.dispatch import (
    EVENT_FACING,
    EVENT_GATE,
    EVENT_PASS,
    EVENT_REISSUE,
    EVENT_REMINDER,
    SCAN_BASH,
    SCAN_NONE,
    SCAN_TEXT,
    Extraction,
)
from core.types import ExtractorRecord


# Body-bearing gh/gh-api-safe flags that mark a command as a post. This list is
# the SURFACE-CHOICE signal only; the command body is scanned by scan_bash.
_GH_POST_FLAGS = {
    "-b",
    "--body",
    "-F",
    "--body-file",
    "-f",
    "--field",
    "--raw-field",
    "--notes",
    "-m",
    "--message",
    "-t",
    "--title",
}


def read_path(data: Any, path: str) -> Any:
    value = data
    for part in path.split("."):
        if isinstance(value, dict) and part in value:
            value = value[part]
        else:
            return None
    return value


def as_text(value: Any) -> str | None:
    if isinstance(value, str):
        return value
    if isinstance(value, list) and all(isinstance(item, str) for item in value):
        return "\n".join(value)
    return None


def text_content(value: Any) -> list[str]:
    if isinstance(value, str):
        return [value]
    if isinstance(value, list):
        output: list[str] = []
        for item in value:
            output.extend(text_content(item))
        return output
    if isinstance(value, dict):
        if isinstance(value.get("text"), str):
            return [value["text"]]
        if isinstance(value.get("content"), str):
            return [value["content"]]
        if isinstance(value.get("content"), list):
            return text_content(value["content"])
    return []


def assistant_text_from_object(value: Any) -> list[str]:
    if not isinstance(value, dict):
        return []

    if value.get("role") == "assistant":
        return text_content(value.get("content"))

    message = value.get("message")
    if isinstance(message, dict) and message.get("role") == "assistant":
        return text_content(message.get("content"))

    if value.get("type") in {"assistant", "assistant_message"}:
        return text_content(value.get("content") or value.get("message"))

    return []


def transcript_last_assistant_text(path: str) -> str | None:
    raw = read_text_file(path)
    if raw is None:
        return None

    stripped = raw.strip()
    if not stripped:
        return None

    last_text: str | None = None
    try:
        parsed = json.loads(stripped)
    except json.JSONDecodeError:
        parsed = None

    if isinstance(parsed, list):
        for item in parsed:
            parts = assistant_text_from_object(item)
            if parts:
                last_text = "\n".join(parts)
        return last_text

    if isinstance(parsed, dict):
        parts = assistant_text_from_object(parsed)
        if parts:
            return "\n".join(parts)

    for line in raw.splitlines():
        if not line.strip():
            continue
        try:
            item = json.loads(line)
        except json.JSONDecodeError:
            continue
        parts = assistant_text_from_object(item)
        if parts:
            last_text = "\n".join(parts)

    return last_text


def collect_body_texts(value: Any, body_keys: frozenset[str]) -> list[str]:
    texts: list[str] = []
    if isinstance(value, dict):
        for key, child in value.items():
            if key in body_keys and isinstance(child, str):
                texts.append(child)
            else:
                texts.extend(collect_body_texts(child, body_keys))
    elif isinstance(value, list):
        for child in value:
            texts.extend(collect_body_texts(child, body_keys))
    return texts


def is_post_capable_mcp_tool(name: str, post_tool_terms: tuple[str, ...]) -> bool:
    # Match the Claude Code/Pi shape: exact gh/gh-api-safe, or an mcp__ tool whose
    # leaf segment (after the final "__") contains a post verb. No loose substring
    # match on arbitrary tool names.
    if name in {"gh", "gh-api-safe"}:
        return True
    if not name.startswith("mcp__"):
        return False
    leaf = name.rsplit("__", 1)[-1].lower()
    return any(term in leaf for term in post_tool_terms)


def _argv_is_gh_post(argv: list[str]) -> bool:
    # Test a parsed argv for a gh/gh-api-safe leading token carrying a post
    # signal: a body-bearing flag or a POST/PATCH/PUT method.
    if not argv or argv[0] not in {"gh", "gh-api-safe"}:
        return False
    for index, token in enumerate(argv):
        if token in _GH_POST_FLAGS:
            return True
        if token.startswith(("--body=", "--body-file=", "--field=", "--raw-field=")):
            return True
        if token.startswith(("--notes=", "--message=", "--title=")):
            return True
        if token in {"-X", "--method"} and index + 1 < len(argv):
            if argv[index + 1].upper() in {"POST", "PATCH", "PUT"}:
                return True
        if token.startswith("--method=") and token.split("=", 1)[1].upper() in {
            "POST",
            "PATCH",
            "PUT",
        }:
            return True
        if token == "--input" or token.startswith("--input="):
            return True
    return False


def is_bash_gh_post(command: Any) -> bool:
    # A Bash command is external (B2) when its first token is gh/gh-api-safe and
    # it carries a post signal. A shell ``-c`` wrapper hides the gh post inside
    # one token, so also unwrap the wrapper and test the inner script's argv: a
    # wrapped ``gh issue create --body ...`` must classify as external too.
    if not isinstance(command, str):
        return False
    if _argv_is_gh_post(command.split()):
        return True
    # The wrapper unwrap needs a shell-aware parse so the quoted inner script is
    # one token; the naive split above keeps the cheap direct path unchanged.
    argv = parse_command_line(command)
    if argv is not None:
        inner = shell_c_inner_script(argv)
        if inner is not None:
            inner_argv = parse_command_line(inner)
            if inner_argv is not None and _argv_is_gh_post(inner_argv):
                return True
    return False


def bash_command(tool_input: Any) -> str | None:
    if isinstance(tool_input, dict):
        return as_text(tool_input.get("command"))
    return None


def is_external_surface(name: str, tool_input: Any, post_tool_terms: tuple[str, ...]) -> bool:
    # External (B2): a post-capable MCP tool / gh CLI tool, or a gh post run
    # through the Bash tool. Everything else is local (B1).
    if is_post_capable_mcp_tool(name, post_tool_terms):
        return True
    if name == "Bash" or name.lower() == "bash":
        return is_bash_gh_post(bash_command(tool_input))
    return False


def is_post_tool(name: str, post_tool_terms: tuple[str, ...]) -> bool:
    # Post-body extraction targets: the gh CLI tools and post-capable MCP tools.
    return is_post_capable_mcp_tool(name, post_tool_terms)


def pre_tool_use_target(name: str, tool_input: Any) -> str | None:
    # The STABLE B1 target the local strike counter keys on. For Edit/Write this
    # is the file path, so a model that revises the body between retries still
    # accumulates strikes against the same path. apply_patch carries no file_path
    # key, so the path is read from the patch body ("*** Add File:" / "*** Update
    # File:"): this keys a breaching patch per-file like Edit/Write, instead of
    # collapsing to one coarse session+turn+tool key under which the first patch
    # blocks and every later patch lands. A pathless patch or Bash returns None:
    # the key falls back to session+turn+tool, a consecutive-block counter that
    # resets on a clean pass.
    lowered = name.lower()
    if lowered not in {"edit", "write", "apply_patch"}:
        return None
    if not isinstance(tool_input, dict):
        return None
    for key in ("file_path", "path", "filename", "file"):
        path = as_text(tool_input.get(key))
        if path:
            return path
    if lowered == "apply_patch":
        patch = _tool_text(tool_input)
        if patch:
            return apply_patch_target(patch)
    return None


def external_target(name: str, tool_input: Any, external_target_keys: tuple[str, ...]) -> str:
    # Operator-visible target for the B2 yield notice: name the post destination
    # so a breach can be retracted fast. Prefer an explicit identifier from the
    # tool input, else fall back to the tool name.
    label = name or "post"
    if isinstance(tool_input, dict):
        # Bash gh posts have no structured identifier, so name the gh subcommand
        # (e.g. "gh pr comment") from the command string.
        if label == "Bash":
            command = as_text(tool_input.get("command"))
            if isinstance(command, str):
                argv = command.split()
                if argv and argv[0] in {"gh", "gh-api-safe"}:
                    return " ".join(argv[:3])
        for key in external_target_keys:
            value = tool_input.get(key)
            if isinstance(value, (str, int)) and str(value):
                return f"{label} {value}"
    return label


def _existing_blocked() -> bool:
    # Reproduce the old TRIPWIRE_EXISTING_BLOCKED per-turn dedupe signal: a
    # duplicate breach already handled this turn takes no second strike and no
    # second notice.
    value = os.environ.get("TRIPWIRE_EXISTING_BLOCKED", "")
    return value.strip().lower() in {"1", "true", "yes"}


def _record(payload: dict[str, Any], tool: str, target: str | None) -> ExtractorRecord:
    return ExtractorRecord(
        session=str(read_path(payload, "session_id") or ""),
        turn=str(read_path(payload, "turn_id") or ""),
        tool=tool,
        target=target,
        texts=[],
    )


def _pass(payload: dict[str, Any]) -> Extraction:
    return Extraction(
        record=_record(payload, "", None),
        event_class=EVENT_PASS,
        scan_mode=SCAN_NONE,
    )


def _tool_text(tool_input: Any) -> str | None:
    # Mirror the codex.sh "tool-text" mode key order: the first non-empty key
    # wins. apply_patch carries its body in "command"; Edit in "new_string";
    # Write in "content".
    if isinstance(tool_input, dict):
        for key in ("content", "new_string", "text", "patch", "command", "input"):
            text = as_text(tool_input.get(key))
            if text:
                return text
    elif isinstance(tool_input, str):
        return tool_input
    return None


def _extract_pre_tool_use(payload: dict[str, Any], config: Config) -> Extraction:
    name = read_path(payload, "tool_name") or ""
    if not isinstance(name, str):
        name = str(name)
    tool_input = read_path(payload, "tool_input")

    is_external = is_external_surface(name, tool_input, config.post_tool_terms)
    surface = "external" if is_external else "local"
    if is_external:
        target = external_target(name, tool_input, config.external_target_keys)
    else:
        target = pre_tool_use_target(name, tool_input)
    record = _record(payload, name, target)

    gate_args = {
        "record": record,
        "event_class": EVENT_GATE,
        "surface": surface,
        "existing_blocked": _existing_blocked(),
    }

    if name == "Bash":
        command = bash_command(tool_input)
        if not command:
            return Extraction(scan_mode=SCAN_NONE, unresolved=True, **gate_args)
        # The command body routes through scan_bash, never through is_bash_gh_post.
        # For a LOCAL Bash write the strike TARGET is the first prose sink the
        # command writes, so it keys per-file like Edit/Write. An external gh post
        # keeps its B2 target. No resolvable sink leaves the coarse
        # session+turn+tool key.
        record.texts = [command]
        if not is_external:
            record.target = bash_prose_sink(command)
        return Extraction(scan_mode=SCAN_BASH, **gate_args)

    if name in {"apply_patch", "Edit", "Write"}:
        text = _tool_text(tool_input)
        if not text:
            return Extraction(scan_mode=SCAN_NONE, unresolved=True, **gate_args)
        record.texts = [text]
        return Extraction(scan_mode=SCAN_TEXT, **gate_args)

    # Every other tool: a post body if the tool is post-capable, else pass. An
    # empty post body fails closed; a non-post tool passes.
    if is_post_tool(name, config.post_tool_terms):
        texts = collect_body_texts(tool_input, frozenset(config.post_text_keys))
        if not texts:
            return Extraction(scan_mode=SCAN_NONE, unresolved=True, **gate_args)
        record.texts = ["\n".join(texts)]
        return Extraction(scan_mode=SCAN_TEXT, **gate_args)

    return _pass(payload)


def _assistant_message(payload: dict[str, Any]) -> str | None:
    # Mirror codex.sh "assistant-message": prefer last_assistant_message, then
    # read the last assistant text from either transcript path.
    value = read_path(payload, "last_assistant_message")
    if isinstance(value, str) and value:
        return value
    for path_key in ("transcript_path", "agent_transcript_path"):
        transcript_path = read_path(payload, path_key)
        if isinstance(transcript_path, str) and transcript_path:
            text = transcript_last_assistant_text(transcript_path)
            if isinstance(text, str) and text:
                return text
    return None


def _extract_stop(payload: dict[str, Any], tool: str) -> Extraction:
    record = _record(payload, tool, None)
    facing = {
        "record": record,
        "event_class": EVENT_FACING,
        "existing_blocked": _existing_blocked(),
    }

    message = _assistant_message(payload)
    if message is None or not message.strip():
        return Extraction(scan_mode=SCAN_NONE, unresolved=True, **facing)

    record.texts = [message]
    return Extraction(scan_mode=SCAN_TEXT, **facing)


def extract(event: str, payload: dict[str, Any], config: Config) -> Extraction:
    """Return the normalised Extraction for one Codex event.

    Routes the registered events: PreToolUse (gate), Stop and SubagentStop
    (Tier A facing), UserPromptSubmit (Tier A re-issue), SessionStart and
    SubagentStart (the rules reminder). Every other event is a pass the core
    ignores.
    """
    if event == "PreToolUse":
        return _extract_pre_tool_use(payload, config)
    if event == "Stop":
        return _extract_stop(payload, "Stop")
    if event == "SubagentStop":
        return _extract_stop(payload, "SubagentStop")
    if event == "UserPromptSubmit":
        return Extraction(
            record=_record(payload, "", None),
            event_class=EVENT_REISSUE,
            scan_mode=SCAN_NONE,
        )
    if event in {"SessionStart", "SubagentStart"}:
        return Extraction(
            record=_record(payload, "", None),
            event_class=EVENT_REMINDER,
            scan_mode=SCAN_NONE,
        )

    return _pass(payload)
