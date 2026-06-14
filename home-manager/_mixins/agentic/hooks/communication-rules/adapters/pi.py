#!/usr/bin/env python3
"""Extract Pi extension event payloads for the shared adapter contract."""

from __future__ import annotations

import json
import os
import shlex
import sys
from pathlib import Path
from typing import Any, TypeGuard


POST_TOOL_NAMES = {"gh", "gh-api-safe"}

# Apply-patch style tools that pi packages can register on top of the four
# built-ins. The patch body carries the prose that lands on disk, so scan it.
PATCH_TOOL_NAMES = {"apply_patch", "applypatch", "apply-patch", "patch"}

# Baked fallbacks for the post-detection data. fragment.nix is the single
# canonical source; these copies apply only when TRIPWIRE_POLICY_JSON is unset or
# unreadable, such as in the fixture harnesses.
_FALLBACK_POST_TEXT_KEYS = (
    "body",
    "comment",
    "comments",
    "content",
    "description",
    "message",
    "messages",
    "note",
    "notes",
    "review",
    "summary",
    "text",
    "title",
)

_FALLBACK_POST_TOOL_TERMS = (
    "comment",
    "create",
    "edit",
    "post",
    "publish",
    "reply",
    "review",
    "send",
    "submit",
    "update",
    "write",
)


def _load_post_detection() -> dict[str, tuple[str, ...]]:
    # Read the canonical post-detection lists from policy.json (via
    # TRIPWIRE_POLICY_JSON). Fall back to the baked copies on any failure so the
    # adapter stays usable without the generated policy file.
    fallback = {
        "postTextKeys": _FALLBACK_POST_TEXT_KEYS,
        "postToolTerms": _FALLBACK_POST_TOOL_TERMS,
    }
    path = os.environ.get("TRIPWIRE_POLICY_JSON")
    if not path:
        return fallback
    try:
        raw = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return fallback

    node = raw
    for key in ("communicationRules", "detectionPolicy", "postDetection"):
        if not isinstance(node, dict):
            node = None
            break
        node = node.get(key)
    if not isinstance(node, dict):
        return fallback

    result = dict(fallback)
    for key in ("postTextKeys", "postToolTerms"):
        value = node.get(key)
        if isinstance(value, list) and all(isinstance(item, str) for item in value):
            result[key] = tuple(value)
    return result


_POST_DETECTION = _load_post_detection()

# Text-bearing keys inside an MCP/post-capable tool's structured input.
POST_TEXT_KEYS = frozenset(_POST_DETECTION["postTextKeys"])

# Verb fragments that mark an MCP tool as able to post or mutate external state.
POST_TOOL_TERMS = _POST_DETECTION["postToolTerms"]


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


def is_post_capable_mcp_tool(name: str) -> bool:
    if not name.startswith("mcp__"):
        return False
    leaf = name.rsplit("__", 1)[-1].lower()
    return any(term in leaf for term in POST_TOOL_TERMS)


def collect_post_texts(value: Any, key: str = "") -> list[str]:
    if isinstance(value, str):
        return [value] if key.lower() in POST_TEXT_KEYS else []
    if isinstance(value, list):
        output: list[str] = []
        for item in value:
            output.extend(collect_post_texts(item, key))
        return output
    if is_record(value):
        output = []
        for child_key, child_value in value.items():
            output.extend(collect_post_texts(child_value, str(child_key)))
        return output
    return []


def tool_call_payload(event: dict[str, Any]) -> tuple[str, str | None]:
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

    if is_post_capable_mcp_tool(name):
        texts = collect_post_texts(input_value)
        return ("text", "\n\n".join(texts)) if texts else ("fail", None)

    return "pass", None


def write_action(output_dir: Path, action: str, payload: str | None = None) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "action").write_text(action + "\n", encoding="utf-8")
    if payload is not None:
        (output_dir / "payload").write_text(payload, encoding="utf-8")


def extract(event_name: str, event: dict[str, Any], output_dir: Path) -> int:
    if event_name == "tool_call":
        action, payload = tool_call_payload(event)
        write_action(output_dir, action, payload)
        return 0

    if event_name == "message_end":
        message = event.get("message")
        if not is_record(message):
            write_action(output_dir, "fail")
            return 0
        text = message_text(message)
        if text is None:
            write_action(output_dir, "fail")
        elif text == "":
            write_action(output_dir, "pass")
        else:
            write_action(output_dir, "correction", text)
        return 0

    if event_name == "tool_result":
        text = tool_result_text(event)
        if text is None:
            write_action(output_dir, "fail")
        elif text == "":
            write_action(output_dir, "pass")
        else:
            write_action(output_dir, "text", text)
        return 0

    write_action(output_dir, "pass")
    return 0


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: pi.py <event> <output-dir>", file=sys.stderr)
        return 2

    event_name = sys.argv[1]
    output_dir = Path(sys.argv[2])
    try:
        loaded = json.load(sys.stdin)
    except json.JSONDecodeError:
        write_action(output_dir, "fail")
        return 0

    event = event_payload(loaded)
    if event is None:
        write_action(output_dir, "fail")
        return 0

    return extract(event_name, event, output_dir)


if __name__ == "__main__":
    raise SystemExit(main())
