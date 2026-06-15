"""Pi event extraction for the Communication Rules core.

Moved from ``adapters/pi.py``. The extraction logic is unchanged in substance:
the event-payload reader, the tool-input and tool-name readers, the text-block
helpers, the message-text and tool-result-text readers, the edit-text reader,
the post-command reader, the patch-text reader, the mcp-tool check, the
post-text collector, and the ``tool_call`` payload all behave as before. The
change is the seam: instead of writing an action word and a payload file, this
module returns the normalised ``Extraction`` the dispatcher's shared middle
consumes.

The surface decision (local B1 versus external B2) and the operator target move
here from the old Pi TypeScript extension (``isExternalSurface``,
``externalTarget``, ``localTarget``). The core picks the limit and key namespace
from the surface; this module only classifies it.

Two behaviour points the proposal pins down:

- Bash tool calls (and gh / gh-api-safe post commands) put the command text into
  the record's ``texts`` and route through ``scan_bash`` (``scan_mode = bash``),
  NOT through the post-command / patch-text bash detection. The SURFACE choice
  uses the external check below; the BODY detection is ``scan_bash``.
- The post-detection lists (post text keys, post tool terms, external target
  keys) are read from ``core.config``, not baked here. There is no fallback copy
  in this module.

``turn`` is always ``None`` for Pi: its events carry no turn id, so the strike
counter is a consecutive-block counter keyed on session, tool, and a stable
target. The Pi session id is passed straight through; the non-empty session
guarantee is enforced in ``core.state``.
"""

from __future__ import annotations

import os
import shlex
from typing import Any, TypeGuard

from core.config import Config
from core.detection import bash_prose_sink
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


# The gh CLI tools Pi packages can register. A post run through one is external
# (B2). This is the SURFACE-CHOICE signal only; the command body is scanned by
# scan_bash.
POST_TOOL_NAMES = {"gh", "gh-api-safe"}

# Apply-patch style tools that pi packages can register on top of the four
# built-ins. The patch body carries the prose that lands on disk, so scan it.
PATCH_TOOL_NAMES = {"apply_patch", "applypatch", "apply-patch", "patch"}

# File tools whose stable target is the file path: the B1 strike counter keys on
# the path, so a model that revises the body between retries still walks the cap.
# Mirrors the old Pi extension's localTarget set.
_FILE_TOOL_NAMES = {
    "write",
    "edit",
    "multiedit",
    "multi_edit",
    "patch",
    "apply_patch",
    "applypatch",
    "str_replace",
}

_FILE_TARGET_KEYS = ("path", "file_path", "filePath", "filename", "file")


def is_record(value: Any) -> TypeGuard[dict[str, Any]]:
    return isinstance(value, dict)


def event_payload(value: Any) -> dict[str, Any] | None:
    if not is_record(value):
        return None
    for key in ("event", "payload"):
        nested = value.get(key)
        if is_record(nested):
            return nested
    return value


def tool_input(event: dict[str, Any]) -> dict[str, Any]:
    value = event.get("input")
    if is_record(value):
        return value
    value = event.get("args")
    if is_record(value):
        return value
    return event


def tool_name(event: dict[str, Any]) -> str:
    for key in ("toolName", "tool_name", "name", "tool"):
        value = event.get(key)
        if isinstance(value, str):
            return value
    return ""


def string_value(value: Any) -> str | None:
    return value if isinstance(value, str) else None


def text_blocks(value: Any, *, assistant: bool = False) -> list[str]:
    if isinstance(value, str):
        return [value]
    if isinstance(value, list):
        parts: list[str] = []
        for item in value:
            parts.extend(text_blocks(item, assistant=assistant))
        return parts
    if not is_record(value):
        return []
    block_type = value.get("type")
    if assistant and block_type in {"thinking", "toolCall"}:
        return []
    text = value.get("text")
    return [text] if isinstance(text, str) else []


def message_text(message: dict[str, Any]) -> str | None:
    if message.get("role") != "assistant":
        return ""
    if message.get("stopReason") == "toolUse":
        return ""
    parts = text_blocks(message.get("content"), assistant=True)
    return "\n\n".join(parts) if parts else ""


def tool_result_text(event: dict[str, Any]) -> str | None:
    if tool_name(event) != "subagent":
        return ""
    parts = text_blocks(event.get("content"))
    if not parts and is_record(event.get("result")):
        parts = text_blocks(event["result"].get("content"))
    if not parts:
        return None
    return "\n\n".join(parts)


def edit_text(input_value: dict[str, Any]) -> str | None:
    edits = input_value.get("edits")
    if not isinstance(edits, list):
        return None
    parts: list[str] = []
    for edit in edits:
        if not is_record(edit):
            return None
        text = string_value(edit.get("newText"))
        if text is None:
            return None
        parts.append(text)
    return "\n\n".join(parts) if parts else None


def post_command(name: str, input_value: dict[str, Any]) -> str | None:
    command = string_value(input_value.get("command"))
    if command:
        return command

    args = input_value.get("args", input_value.get("argv"))
    if isinstance(args, list) and all(isinstance(arg, str) for arg in args):
        return " ".join([shlex.quote(name), *(shlex.quote(arg) for arg in args)])

    return None


def patch_text(input_value: dict[str, Any]) -> str | None:
    for key in ("patch", "content", "input", "text", "diff"):
        text = string_value(input_value.get(key))
        if text is not None:
            return text
    return None


def is_post_capable_mcp_tool(name: str, post_tool_terms: tuple[str, ...]) -> bool:
    if not name.startswith("mcp__"):
        return False
    leaf = name.rsplit("__", 1)[-1].lower()
    return any(term in leaf for term in post_tool_terms)


def collect_post_texts(value: Any, post_text_keys: frozenset[str], key: str = "") -> list[str]:
    if isinstance(value, str):
        return [value] if key.lower() in post_text_keys else []
    if isinstance(value, list):
        output: list[str] = []
        for item in value:
            output.extend(collect_post_texts(item, post_text_keys, key))
        return output
    if is_record(value):
        output = []
        for child_key, child_value in value.items():
            output.extend(collect_post_texts(child_value, post_text_keys, str(child_key)))
        return output
    return []


def is_external_surface(event: dict[str, Any], config: Config) -> bool:
    # External (B2) surface: the gh CLI tools, or a post-capable MCP tool. A bare
    # "gh "/"gh-api-safe " command also counts. Everything else is local (B1).
    # Mirrors the old Pi extension's isExternalSurface.
    name = tool_name(event).lower()
    if name in {"gh", "gh-api-safe", "github"}:
        return True
    if is_post_capable_mcp_tool(tool_name(event), config.post_tool_terms):
        return True
    input_value = tool_input(event)
    if is_record(input_value):
        command = input_value.get("command", input_value.get("cmd", input_value.get("script")))
        if isinstance(command, str):
            stripped = command.lstrip()
            return stripped.startswith("gh ") or stripped.startswith("gh-api-safe ")
    return False


def external_target(event: dict[str, Any], config: Config) -> str:
    # Operator-visible target for the B2 yield notice: prefer an explicit
    # identifier from the input, else fall back to the tool name. Mirrors the old
    # Pi extension's externalTarget.
    label = tool_name(event) or "post"
    input_value = tool_input(event)
    if is_record(input_value):
        for key in config.external_target_keys:
            value = input_value.get(key)
            if isinstance(value, str) and value:
                return f"{label} {value}"
            if isinstance(value, int) and not isinstance(value, bool):
                return f"{label} {value}"
    return label


def local_target(event: dict[str, Any]) -> str | None:
    # The STABLE B1 target the local strike counter keys on: the file path for
    # write/edit/patch tools. Returns None for bash or a pathless call, so the key
    # falls back to session+tool. Mirrors the old Pi extension's localTarget.
    normalised = tool_name(event).lower().replace("-", "_").replace(".", "_")
    is_file_tool = (
        normalised in _FILE_TOOL_NAMES
        or normalised.endswith("_write")
        or normalised.endswith("_edit")
        or normalised.endswith("_patch")
    )
    if not is_file_tool:
        return None
    input_value = tool_input(event)
    if not is_record(input_value):
        return None
    for key in _FILE_TARGET_KEYS:
        value = input_value.get(key)
        if isinstance(value, str) and value:
            return value
    return None


def tool_call_payload(
    event: dict[str, Any], config: Config
) -> tuple[str, str | None]:
    name = tool_name(event)
    input_value = tool_input(event)

    if name == "write":
        text = string_value(input_value.get("content"))
        return ("text", text) if text is not None else ("fail", None)

    if name == "edit":
        text = edit_text(input_value)
        return ("text", text) if text is not None else ("fail", None)

    if name == "bash":
        command = string_value(input_value.get("command"))
        return ("bash", command) if command is not None else ("fail", None)

    if name in POST_TOOL_NAMES:
        command = post_command(name, input_value)
        return ("bash", command) if command is not None else ("fail", None)

    if name.lower() in PATCH_TOOL_NAMES:
        text = patch_text(input_value)
        return ("text", text) if text is not None else ("fail", None)

    if is_post_capable_mcp_tool(name, config.post_tool_terms):
        texts = collect_post_texts(input_value, frozenset(config.post_text_keys))
        return ("text", "\n\n".join(texts)) if texts else ("fail", None)

    return "pass", None


def _existing_blocked() -> bool:
    # Reproduce the old TRIPWIRE_EXISTING_BLOCKED per-turn dedupe signal: a
    # duplicate breach already handled this turn takes no second strike and no
    # second notice.
    value = os.environ.get("TRIPWIRE_EXISTING_BLOCKED", "")
    return value.strip().lower() in {"1", "true", "yes"}


def _pass(session: str) -> Extraction:
    return Extraction(
        record=ExtractorRecord(session=session, turn=None, tool="", target=None, texts=[]),
        event_class=EVENT_PASS,
        scan_mode=SCAN_NONE,
    )


def _extract_tool_call(event: dict[str, Any], session: str, config: Config) -> Extraction:
    action, payload = tool_call_payload(event, config)

    if action == "pass":
        return _pass(session)

    name = tool_name(event)
    is_external = is_external_surface(event, config)
    surface = "external" if is_external else "local"
    target = external_target(event, config) if is_external else local_target(event)
    record = ExtractorRecord(session=session, turn=None, tool=name, target=target, texts=[])

    gate_args = {
        "record": record,
        "event_class": EVENT_GATE,
        "surface": surface,
        "existing_blocked": _existing_blocked(),
    }

    # An unresolvable body fails closed on this gating surface: deny or yield
    # under the cap, never pass.
    if action == "fail" or payload is None:
        return Extraction(scan_mode=SCAN_NONE, unresolved=True, **gate_args)

    if action == "bash":
        # The command body routes through scan_bash, never through the
        # post-command / patch-text bash detection. For a LOCAL Bash write the
        # strike TARGET is the first prose sink the command writes, so it keys
        # per-file like write/edit. An external gh post keeps its B2 target. No
        # resolvable sink leaves the coarse session+tool key.
        record.texts = [payload]
        if not is_external:
            record.target = bash_prose_sink(payload)
        return Extraction(scan_mode=SCAN_BASH, **gate_args)

    # action == "text": prose tools and post bodies.
    record.texts = [payload]
    return Extraction(scan_mode=SCAN_TEXT, **gate_args)


def _extract_message_end(event: dict[str, Any], session: str) -> Extraction:
    record = ExtractorRecord(session=session, turn=None, tool="message_end", target=None, texts=[])
    facing = {
        "record": record,
        "event_class": EVENT_FACING,
        "existing_blocked": _existing_blocked(),
    }

    message = event.get("message")
    if not is_record(message):
        return Extraction(scan_mode=SCAN_NONE, unresolved=True, **facing)

    text = message_text(message)
    if text is None:
        return Extraction(scan_mode=SCAN_NONE, unresolved=True, **facing)
    if text == "":
        return Extraction(scan_mode=SCAN_NONE, **facing)

    record.texts = [text]
    return Extraction(scan_mode=SCAN_TEXT, **facing)


def _extract_tool_result(event: dict[str, Any], session: str, config: Config) -> Extraction:
    record = ExtractorRecord(session=session, turn=None, tool="tool_result", target=None, texts=[])
    gate_args = {
        "record": record,
        "event_class": EVENT_GATE,
        "surface": "local",
        "existing_blocked": _existing_blocked(),
    }

    text = tool_result_text(event)
    if text is None:
        return Extraction(scan_mode=SCAN_NONE, unresolved=True, **gate_args)
    if text == "":
        return _pass(session)

    record.texts = [text]
    return Extraction(scan_mode=SCAN_TEXT, **gate_args)


def extract(event: str, payload: dict[str, Any], config: Config) -> Extraction:
    """Return the normalised Extraction for one Pi event.

    Routes the registered handlers: ``tool_call`` (gate), ``message_end``
    (Tier A facing), ``tool_result`` (gate, subagent only). The ``context``
    reminder and ``input`` events are a pass the core ignores; the shim still
    injects the rules via the Tier A injection flags.

    The Pi event payload may be nested under ``event`` or ``payload``; an
    unreadable shape fails closed on a gating surface.
    """
    session_id = payload.get("session_id")
    session = session_id if isinstance(session_id, str) else ""

    if event == "context":
        # The context build carries no body. The core reads the once-per-session
        # base-rules dedupe and the pending-reissue flag from the record session
        # and returns the injection flags; the shim applies them.
        record = ExtractorRecord(session=session, turn=None, tool="context", target=None, texts=[])
        return Extraction(record=record, event_class=EVENT_CONTEXT, scan_mode=SCAN_NONE)

    inner = event_payload(payload)
    if inner is None:
        # A broken payload fails closed on a gating handler; message_end stays
        # Tier A (re-issue, not block). Map both to an unresolved record.
        record = ExtractorRecord(session=session, turn=None, tool=event, target=None, texts=[])
        if event == "message_end":
            return Extraction(
                record=record,
                event_class=EVENT_FACING,
                scan_mode=SCAN_NONE,
                unresolved=True,
                existing_blocked=_existing_blocked(),
            )
        if event in {"tool_call", "tool_result"}:
            return Extraction(
                record=record,
                event_class=EVENT_GATE,
                surface="local",
                scan_mode=SCAN_NONE,
                unresolved=True,
                existing_blocked=_existing_blocked(),
            )
        return _pass(session)

    if event == "tool_call":
        return _extract_tool_call(inner, session, config)
    if event == "message_end":
        return _extract_message_end(inner, session)
    if event == "tool_result":
        return _extract_tool_result(inner, session, config)

    return _pass(session)
