#!/usr/bin/env python3
"""Extract Claude Code hook payloads for Communication Rules gates."""

from __future__ import annotations

import json
import hashlib
import os
import sys
from pathlib import Path
from typing import Any


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

_FALLBACK_EXTERNAL_TARGET_KEYS = (
    "url",
    "pull_number",
    "issue_number",
    "number",
    "pullRequestId",
    "issueId",
    "discussionId",
    "id",
    "path",
    "repo",
    "repository",
    "owner",
)


def _load_post_detection() -> dict[str, tuple[str, ...]]:
    # Read the canonical post-detection lists from policy.json (via
    # TRIPWIRE_POLICY_JSON). Fall back to the baked copies on any failure so the
    # adapter stays usable without the generated policy file.
    fallback: dict[str, tuple[str, ...]] = {
        "postTextKeys": _FALLBACK_POST_TEXT_KEYS,
        "postToolTerms": _FALLBACK_POST_TOOL_TERMS,
        "externalTargetKeys": _FALLBACK_EXTERNAL_TARGET_KEYS,
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
    for key in ("postTextKeys", "postToolTerms", "externalTargetKeys"):
        value = node.get(key)
        if isinstance(value, list) and all(isinstance(item, str) for item in value):
            result[key] = tuple(value)
    return result


_POST_DETECTION = _load_post_detection()
POST_TEXT_KEYS = frozenset(_POST_DETECTION["postTextKeys"])
POST_TOOL_TERMS = _POST_DETECTION["postToolTerms"]
EXTERNAL_TARGET_KEYS = _POST_DETECTION["externalTargetKeys"]


def load_payload() -> dict[str, Any] | None:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        return None
    return payload if isinstance(payload, dict) else None


def write_text(path: str, text: str) -> None:
    Path(path).write_text(text, encoding="utf-8")


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
    try:
        raw = Path(path).read_text(encoding="utf-8")
    except OSError:
        return None
    except UnicodeDecodeError:
        return None

    last_text: str | None = None
    stripped = raw.strip()
    if not stripped:
        return None

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


def is_post_capable_mcp_tool(tool_name: str) -> bool:
    if not tool_name.startswith("mcp__"):
        return False
    leaf = tool_name.rsplit("__", 1)[-1].lower()
    return any(term in leaf for term in POST_TOOL_TERMS)


# Body-bearing gh/gh-api-safe flags that mark a command as a post. Mirrors the
# scanner's is_known_post_command signal so a gh post run through the Bash tool
# is classified external (B2), the same as a post-capable MCP tool.
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


def is_bash_gh_post(command: str) -> bool:
    # The Bash command is an external (B2) surface when its first token is gh or
    # gh-api-safe and it carries a post signal: a body-bearing flag or a
    # POST/PATCH/PUT method. Read-only gh calls stay local (B1).
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


def pre_tool_use_is_external(payload: dict[str, Any]) -> bool:
    # External (B2): a post-capable MCP tool, or a gh/gh-api-safe post run through
    # the Bash tool. Everything else is local (B1).
    tool_name = payload.get("tool_name")
    if not isinstance(tool_name, str):
        return False
    if is_post_capable_mcp_tool(tool_name):
        return True
    if tool_name == "Bash":
        tool_input = payload.get("tool_input")
        if isinstance(tool_input, dict):
            command = tool_input.get("command")
            if isinstance(command, str):
                return is_bash_gh_post(command)
    return False


def collect_post_texts(value: Any, key: str = "") -> list[str]:
    if isinstance(value, str):
        return [value] if key.lower() in POST_TEXT_KEYS else []

    if isinstance(value, list):
        output: list[str] = []
        for item in value:
            output.extend(collect_post_texts(item, key))
        return output

    if isinstance(value, dict):
        output = []
        for child_key, child_value in value.items():
            output.extend(collect_post_texts(child_value, str(child_key)))
        return output

    return []


def pre_tool_use_target(tool_name: str, tool_input: dict[str, Any]) -> str | None:
    # Identify the STABLE target the B1 strike counter keys on. For file tools
    # this is the file path, so a model that revises the body between retries
    # still accumulates strikes against the same path and yields on the 3rd.
    # Bash has no stable path, so it returns None and the key falls back to
    # session+tool (see pre_tool_use_strike_key). Posts are B2 and key elsewhere.
    if tool_name in {"Write", "Edit", "MultiEdit"}:
        path = tool_input.get("file_path")
        return path if isinstance(path, str) and path else None

    # Bash: no stable path. Returning None yields a session+tool key, a
    # consecutive-block counter that resets on a clean pass. Keying on the
    # command body instead would let a revising model dodge the cap forever, the
    # same bug this fix removes for file tools. Trade-off: two unrelated bash
    # commands with no pass between them share one budget. Rare and acceptable.
    if tool_name == "Bash":
        return None

    if is_post_capable_mcp_tool(tool_name):
        texts = collect_post_texts(tool_input)
        return "\n\n".join(texts) if texts else None

    return None


def pre_tool_use_strike_key(payload: dict[str, Any]) -> str | None:
    tool_name = payload.get("tool_name")
    tool_input = payload.get("tool_input")
    if not isinstance(tool_name, str) or not isinstance(tool_input, dict):
        return None

    # A None target (Bash, or a file tool with no path) falls back to a bare
    # session+tool key so the strike counter is stable rather than per-body.
    target = pre_tool_use_target(tool_name, tool_input)
    if target is None:
        target = ""

    session_id = payload.get("session_id")
    session = session_id if isinstance(session_id, str) else ""
    raw = "\0".join([session, tool_name, target])
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def pre_tool_use_surface(payload: dict[str, Any]) -> str:
    # Sub-tier B1 (local) covers write, edit and bash: cheap to retract because
    # they land on disk, not committed. Sub-tier B2 (external) covers post-capable
    # MCP tools and gh/gh-api-safe posts run through Bash: irretractable the
    # instant they yield. The caller selects the strike limit and notice from this
    # class.
    tool_name = payload.get("tool_name")
    if not isinstance(tool_name, str):
        return ""
    return "external" if pre_tool_use_is_external(payload) else "local"


def pre_tool_use_external_strike_key(payload: dict[str, Any]) -> str:
    # Sub-tier B2 keys on a STABLE identity (session + tool), not the body hash,
    # so reworded retries of the same logical post draw down ONE budget. Claude
    # Code PreToolUse has no turn_id, so this is a consecutive-block counter: it
    # accumulates while the same external surface keeps failing and resets the
    # moment any call on that key is allowed or passes. Trade-off: two interleaved
    # posts on the same tool with no pass between them share the budget. Rare and
    # acceptable, since a yield retracts fast via the operator notice.
    tool_name = payload.get("tool_name")
    name = tool_name if isinstance(tool_name, str) else ""
    session_id = payload.get("session_id")
    session = session_id if isinstance(session_id, str) else ""
    raw = "\0".join(["external", session, name])
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def pre_tool_use_external_target(payload: dict[str, Any]) -> str:
    # Operator-visible target for the yield notice: name the post destination so a
    # breach can be retracted fast. Prefer an explicit identifier from the tool
    # input (issue/PR/owner/repo), else fall back to the tool name.
    tool_name = payload.get("tool_name")
    name = tool_name if isinstance(tool_name, str) else "post"
    tool_input = payload.get("tool_input")
    if isinstance(tool_input, dict):
        # Bash gh posts have no structured identifier, so name the gh subcommand
        # (e.g. "gh pr comment") from the command string.
        if name == "Bash":
            command = tool_input.get("command")
            if isinstance(command, str):
                argv = command.split()
                if argv and argv[0] in {"gh", "gh-api-safe"}:
                    return " ".join(argv[:3])
        for key in EXTERNAL_TARGET_KEYS:
            value = tool_input.get(key)
            if isinstance(value, (str, int)) and str(value):
                return "{} {}".format(name, value)
    return name


def extract_pre_tool_use(payload: dict[str, Any], output_path: str) -> str:
    tool_name = payload.get("tool_name")
    tool_input = payload.get("tool_input")
    if not isinstance(tool_name, str):
        return "fail-closed"
    if not isinstance(tool_input, dict):
        return "fail-closed"

    if tool_name == "Write":
        content = tool_input.get("content")
        if not isinstance(content, str):
            return "fail-closed"
        write_text(output_path, content)
        return "scan-text"

    if tool_name == "Edit":
        new_string = tool_input.get("new_string")
        if not isinstance(new_string, str):
            return "fail-closed"
        write_text(output_path, new_string)
        return "scan-text"

    if tool_name == "MultiEdit":
        edits = tool_input.get("edits")
        if not isinstance(edits, list):
            return "fail-closed"
        new_strings = []
        for edit in edits:
            if not isinstance(edit, dict) or not isinstance(edit.get("new_string"), str):
                return "fail-closed"
            new_strings.append(edit["new_string"])
        write_text(output_path, "\n\n".join(new_strings))
        return "scan-text"

    if tool_name == "Bash":
        command = tool_input.get("command")
        if not isinstance(command, str):
            return "fail-closed"
        write_text(output_path, command)
        return "scan-bash"

    if is_post_capable_mcp_tool(tool_name):
        texts = collect_post_texts(tool_input)
        if not texts:
            return "fail-closed"
        write_text(output_path, "\n\n".join(texts))
        return "scan-text"

    return "pass"


def extract_stop(payload: dict[str, Any], output_path: str) -> str:
    direct = payload.get("last_assistant_message")
    if isinstance(direct, str) and direct.strip():
        write_text(output_path, direct)
        return "scan-text"

    transcript_path = payload.get("transcript_path")
    if not isinstance(transcript_path, str) or not transcript_path:
        return "fail-closed"

    text = transcript_last_assistant_text(transcript_path)
    if text is None or not text.strip():
        return "fail-closed"

    write_text(output_path, text)
    return "scan-text"


def extract_subagent_stop(payload: dict[str, Any], output_path: str) -> str:
    # SubagentStop shares the Stop input contract: the subagent's final text is
    # read from the same transcript via transcript_path. Claude Code does not
    # populate last_assistant_message for SubagentStop, so go straight to the
    # transcript and reuse the Stop extraction logic.
    transcript_path = payload.get("transcript_path")
    if not isinstance(transcript_path, str) or not transcript_path:
        return "fail-closed"

    text = transcript_last_assistant_text(transcript_path)
    if text is None or not text.strip():
        return "fail-closed"

    write_text(output_path, text)
    return "scan-text"


def stop_retry_context(payload: dict[str, Any]) -> str:
    session_id = payload.get("session_id")
    transcript_path = payload.get("transcript_path")
    cwd = payload.get("cwd")
    stop_hook_active = payload.get("stop_hook_active")

    parts = [
        session_id if isinstance(session_id, str) else "",
        transcript_path if isinstance(transcript_path, str) else "",
        cwd if isinstance(cwd, str) else "",
    ]
    digest = hashlib.sha256("\0".join(parts).encode("utf-8")).hexdigest()
    active = stop_hook_active is True
    if isinstance(stop_hook_active, str):
        active = stop_hook_active.lower() in {"1", "true", "yes"}
    return ("active" if active else "inactive") + " " + digest


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(
            "usage: claude-code.py "
            "event|pre-tool-use|stop|subagent-stop|stop-retry-context|"
            "pretooluse-strike-key|pretooluse-surface|"
            "pretooluse-external-strike-key|pretooluse-external-target|"
            "pending-reissue-key [output-path]",
            file=sys.stderr,
        )
        return 2

    payload = load_payload()
    if payload is None:
        return 1

    command = argv[1]
    if command == "event":
        event = payload.get("hook_event_name")
        if isinstance(event, str):
            print(event)
            return 0
        return 1
    if command == "stop-retry-context":
        print(stop_retry_context(payload))
        return 0
    if command == "pretooluse-strike-key":
        key = pre_tool_use_strike_key(payload)
        if key is None:
            return 1
        print(key)
        return 0
    if command == "pretooluse-surface":
        print(pre_tool_use_surface(payload))
        return 0
    if command == "pretooluse-external-strike-key":
        print(pre_tool_use_external_strike_key(payload))
        return 0
    if command == "pretooluse-external-target":
        print(pre_tool_use_external_target(payload))
        return 0
    if command == "pending-reissue-key":
        # Key the Stop -> UserPromptSubmit re-issue handoff on the session so the
        # next user turn in the same session picks up the flag.
        session_id = payload.get("session_id")
        print(session_id if isinstance(session_id, str) and session_id else "fallback")
        return 0

    if len(argv) < 3:
        return 2

    if command == "pre-tool-use":
        print(extract_pre_tool_use(payload, argv[2]))
        return 0
    if command == "stop":
        print(extract_stop(payload, argv[2]))
        return 0
    if command == "subagent-stop":
        print(extract_subagent_stop(payload, argv[2]))
        return 0

    print(f"unknown command: {command}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
