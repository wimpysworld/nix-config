"""Claude Code event extraction for the Communication Rules core.

Moved from ``adapters/claude-code.py``. The extraction logic is unchanged in
substance: the pre-tool-use, stop, and subagent-stop extractors, the transcript
reader, the post-text collector, the mcp-tool check, and the target and surface
helpers all behave as before. The change is the seam: instead of writing the
body to a temp file and printing an action word, this module returns the
normalised ``Extraction`` the dispatcher's shared middle consumes.

Two behaviour points the proposal pins down:

- Bash tool calls put the command text into the record's ``texts`` and route
  through ``scan_bash`` (``scan_mode = bash``), NOT through any parallel gh-post
  body detection. The SURFACE choice (local B1 versus external B2) still uses
  the external check below, mirroring the old adapter.
- The post-detection lists (post text keys, post tool terms, external target
  keys) are read from ``core.config``, not baked here. There is no fallback copy
  in this module.

``turn`` is always ``None`` for Claude Code: its PreToolUse payload carries no
turn id, so the strike counter is a consecutive-block counter keyed on session,
tool, and a stable target.
"""

from __future__ import annotations

import os
from typing import Any

from core.config import Config
from core.dispatch import (
    EVENT_FACING,
    EVENT_GATE,
    EVENT_PASS,
    EVENT_REISSUE,
    SCAN_BASH,
    SCAN_NONE,
    SCAN_TEXT,
    Extraction,
)
from core.detection import read_text_file
from core.types import ExtractorRecord


# Body-bearing gh/gh-api-safe flags that mark a command as a post. Mirrors the
# scanner's is_known_post_command signal so a gh post run through the Bash tool
# is classified external (B2), the same as a post-capable MCP tool. This list is
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


def is_post_capable_mcp_tool(tool_name: str, post_tool_terms: tuple[str, ...]) -> bool:
    if not tool_name.startswith("mcp__"):
        return False
    leaf = tool_name.rsplit("__", 1)[-1].lower()
    return any(term in leaf for term in post_tool_terms)


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

    last_text: str | None = None
    stripped = raw.strip()
    if not stripped:
        return None

    import json

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


def collect_post_texts(value: Any, post_text_keys: frozenset[str], key: str = "") -> list[str]:
    if isinstance(value, str):
        return [value] if key.lower() in post_text_keys else []

    if isinstance(value, list):
        output: list[str] = []
        for item in value:
            output.extend(collect_post_texts(item, post_text_keys, key))
        return output

    if isinstance(value, dict):
        output = []
        for child_key, child_value in value.items():
            output.extend(collect_post_texts(child_value, post_text_keys, str(child_key)))
        return output

    return []


def is_bash_gh_post(command: str) -> bool:
    # The Bash command is an external (B2) surface when its first token is gh or
    # gh-api-safe and it carries a post signal: a body-bearing flag or a
    # POST/PATCH/PUT method. Read-only gh calls stay local (B1). This is the
    # SURFACE CHOICE only; the body is scanned by scan_bash.
    try:
        argv = command.split()
    except AttributeError:
        return False
    if not argv:
        return False
    first = argv[0]
    if first not in {"gh", "gh-api-safe"}:
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
        if token in {"--input"} or token.startswith("--input="):
            return True
    return False


def is_external_surface(tool_name: str, tool_input: dict[str, Any], config: Config) -> bool:
    # External (B2): a post-capable MCP tool, or a gh/gh-api-safe post run through
    # the Bash tool. Everything else is local (B1).
    if is_post_capable_mcp_tool(tool_name, config.post_tool_terms):
        return True
    if tool_name == "Bash":
        command = tool_input.get("command")
        if isinstance(command, str):
            return is_bash_gh_post(command)
    return False


def pre_tool_use_target(tool_name: str, tool_input: dict[str, Any], config: Config) -> str | None:
    # Identify the STABLE target the B1 strike counter keys on. For file tools
    # this is the file path, so a model that revises the body between retries
    # still accumulates strikes against the same path and yields on the 3rd.
    # Bash has no stable path, so it returns None and the key falls back to
    # session+tool. Posts are B2 and key elsewhere.
    if tool_name in {"Write", "Edit", "MultiEdit"}:
        path = tool_input.get("file_path")
        return path if isinstance(path, str) and path else None

    # Bash: no stable path. Returning None yields a session+tool key, a
    # consecutive-block counter that resets on a clean pass.
    if tool_name == "Bash":
        return None

    if is_post_capable_mcp_tool(tool_name, config.post_tool_terms):
        texts = collect_post_texts(tool_input, frozenset(config.post_text_keys))
        return "\n\n".join(texts) if texts else None

    return None


def external_target(tool_name: str, tool_input: dict[str, Any], config: Config) -> str:
    # Operator-visible target for the B2 yield notice: name the post destination
    # so a breach can be retracted fast. Prefer an explicit identifier from the
    # tool input (issue/PR/owner/repo), else fall back to the tool name.
    name = tool_name if tool_name else "post"
    # Bash gh posts have no structured identifier, so name the gh subcommand
    # (e.g. "gh pr comment") from the command string.
    if name == "Bash":
        command = tool_input.get("command")
        if isinstance(command, str):
            argv = command.split()
            if argv and argv[0] in {"gh", "gh-api-safe"}:
                return " ".join(argv[:3])
    for key in config.external_target_keys:
        value = tool_input.get(key)
        if isinstance(value, (str, int)) and str(value):
            return "{} {}".format(name, value)
    return name


def _existing_blocked() -> bool:
    # Reproduce the old TRIPWIRE_EXISTING_BLOCKED per-turn dedupe signal: a
    # duplicate breach already handled this turn takes no second strike and no
    # second notice. The fixtures set this env to drive the dedupe path.
    value = os.environ.get("TRIPWIRE_EXISTING_BLOCKED", "")
    return value.strip().lower() in {"1", "true", "yes"}


def _pass(session: str) -> Extraction:
    return Extraction(
        record=ExtractorRecord(session=session, turn=None, tool="", target=None, texts=[]),
        event_class=EVENT_PASS,
        scan_mode=SCAN_NONE,
    )


def _extract_pre_tool_use(payload: dict[str, Any], session: str, config: Config) -> Extraction:
    tool_name = payload.get("tool_name")
    tool_input = payload.get("tool_input")

    # An unparseable tool shape fails closed on this gating surface: deny or
    # yield under the cap, never pass.
    if not isinstance(tool_name, str) or not isinstance(tool_input, dict):
        record = ExtractorRecord(session=session, turn=None, tool="", target=None, texts=[])
        return Extraction(
            record=record,
            event_class=EVENT_GATE,
            surface="local",
            scan_mode=SCAN_NONE,
            unresolved=True,
            existing_blocked=_existing_blocked(),
        )

    is_external = is_external_surface(tool_name, tool_input, config)
    surface = "external" if is_external else "local"
    target = external_target(tool_name, tool_input, config) if is_external else pre_tool_use_target(tool_name, tool_input, config)
    record = ExtractorRecord(session=session, turn=None, tool=tool_name, target=target, texts=[])

    gate_args = {
        "record": record,
        "event_class": EVENT_GATE,
        "surface": surface,
        "existing_blocked": _existing_blocked(),
    }

    if tool_name == "Write":
        content = tool_input.get("content")
        if not isinstance(content, str):
            return Extraction(scan_mode=SCAN_NONE, unresolved=True, **gate_args)
        record.texts = [content]
        return Extraction(scan_mode=SCAN_TEXT, **gate_args)

    if tool_name == "Edit":
        new_string = tool_input.get("new_string")
        if not isinstance(new_string, str):
            return Extraction(scan_mode=SCAN_NONE, unresolved=True, **gate_args)
        record.texts = [new_string]
        return Extraction(scan_mode=SCAN_TEXT, **gate_args)

    if tool_name == "MultiEdit":
        edits = tool_input.get("edits")
        if not isinstance(edits, list):
            return Extraction(scan_mode=SCAN_NONE, unresolved=True, **gate_args)
        new_strings = []
        for edit in edits:
            if not isinstance(edit, dict) or not isinstance(edit.get("new_string"), str):
                return Extraction(scan_mode=SCAN_NONE, unresolved=True, **gate_args)
            new_strings.append(edit["new_string"])
        record.texts = ["\n\n".join(new_strings)]
        return Extraction(scan_mode=SCAN_TEXT, **gate_args)

    if tool_name == "Bash":
        command = tool_input.get("command")
        if not isinstance(command, str):
            return Extraction(scan_mode=SCAN_NONE, unresolved=True, **gate_args)
        # The command body routes through scan_bash, never through is_bash_gh_post.
        record.texts = [command]
        return Extraction(scan_mode=SCAN_BASH, **gate_args)

    if is_post_capable_mcp_tool(tool_name, config.post_tool_terms):
        texts = collect_post_texts(tool_input, frozenset(config.post_text_keys))
        if not texts:
            return Extraction(scan_mode=SCAN_NONE, unresolved=True, **gate_args)
        record.texts = ["\n\n".join(texts)]
        return Extraction(scan_mode=SCAN_TEXT, **gate_args)

    # Unknown tool: not a gating surface, pass.
    return _pass(session)


def _extract_stop(payload: dict[str, Any], session: str) -> Extraction:
    record = ExtractorRecord(session=session, turn=None, tool="Stop", target=None, texts=[])
    facing = {
        "record": record,
        "event_class": EVENT_FACING,
        "existing_blocked": _existing_blocked(),
    }

    direct = payload.get("last_assistant_message")
    if isinstance(direct, str) and direct.strip():
        record.texts = [direct]
        return Extraction(scan_mode=SCAN_TEXT, **facing)

    transcript_path = payload.get("transcript_path")
    if not isinstance(transcript_path, str) or not transcript_path:
        return Extraction(scan_mode=SCAN_NONE, unresolved=True, **facing)

    text = transcript_last_assistant_text(transcript_path)
    if text is None or not text.strip():
        return Extraction(scan_mode=SCAN_NONE, unresolved=True, **facing)

    record.texts = [text]
    return Extraction(scan_mode=SCAN_TEXT, **facing)


def _extract_subagent_stop(payload: dict[str, Any], session: str) -> Extraction:
    # SubagentStop shares the Stop input contract: the subagent's final text is
    # read from the same transcript via transcript_path. Claude Code does not
    # populate last_assistant_message for SubagentStop, so go straight to the
    # transcript and reuse the Stop extraction logic.
    record = ExtractorRecord(session=session, turn=None, tool="SubagentStop", target=None, texts=[])
    facing = {
        "record": record,
        "event_class": EVENT_FACING,
        "existing_blocked": _existing_blocked(),
    }

    transcript_path = payload.get("transcript_path")
    if not isinstance(transcript_path, str) or not transcript_path:
        return Extraction(scan_mode=SCAN_NONE, unresolved=True, **facing)

    text = transcript_last_assistant_text(transcript_path)
    if text is None or not text.strip():
        return Extraction(scan_mode=SCAN_NONE, unresolved=True, **facing)

    record.texts = [text]
    return Extraction(scan_mode=SCAN_TEXT, **facing)


def extract(event: str, payload: dict[str, Any], config: Config) -> Extraction:
    """Return the normalised Extraction for one Claude Code event.

    Routes the registered events: PreToolUse (gate), Stop and SubagentStop
    (Tier A facing), UserPromptSubmit (Tier A re-issue). Every other event
    (SessionStart and the rest) is a pass the core ignores.
    """
    session_id = payload.get("session_id")
    session = session_id if isinstance(session_id, str) else ""

    if event == "PreToolUse":
        return _extract_pre_tool_use(payload, session, config)
    if event == "Stop":
        return _extract_stop(payload, session)
    if event == "SubagentStop":
        return _extract_subagent_stop(payload, session)
    if event == "UserPromptSubmit":
        return Extraction(
            record=ExtractorRecord(session=session, turn=None, tool="", target=None, texts=[]),
            event_class=EVENT_REISSUE,
            scan_mode=SCAN_NONE,
        )

    return _pass(session)
