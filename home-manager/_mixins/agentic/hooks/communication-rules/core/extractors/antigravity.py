"""Google Antigravity CLI extraction for PreInvocation, PreToolUse, and synthetic Stop."""

from __future__ import annotations

import json

from core.dispatch import EVENT_CONTEXT, EVENT_REISSUE, Extraction
from core.extractors import assistant_reply, first_string, record, tool_call


def _parse_json_object(value) -> dict | None:
    if isinstance(value, dict):
        return value
    if isinstance(value, str) and value:
        try:
            parsed = json.loads(value)
        except ValueError:
            return None
        return parsed if isinstance(parsed, dict) else None
    return None


def _normalise_mcp_call(args: dict) -> tuple[str, dict] | None:
    server = first_string(args, ("ServerName", "serverName", "server"))
    nested_call = args.get("toolCall")
    if isinstance(nested_call, dict):
        tool = first_string(nested_call, ("name", "ToolName", "toolName"))
        raw_args = nested_call.get(
            "args",
            nested_call.get("arguments", nested_call.get("argumentsJson")),
        )
    else:
        tool = first_string(args, ("ToolName", "toolName", "tool", "name"))
        raw_args = args.get(
            "Arguments",
            args.get("arguments", args.get("argumentsJson", args.get("args"))),
        )
    if not tool:
        return None
    parsed_args = _parse_json_object(raw_args)
    if parsed_args is None:
        return None
    qualified = f"mcp__{server}__{tool}" if server else tool
    return qualified, parsed_args


def extract(event: str, payload: dict, config=None) -> Extraction:
    if event == "PreInvocation":
        invocation_num = payload.get("invocationNum", payload.get("invocation_num", 0))
        if (
            isinstance(invocation_num, int)
            and not isinstance(invocation_num, bool)
            and invocation_num > 0
        ):
            return Extraction(record(payload), EVENT_CONTEXT)
        return Extraction(record(payload), EVENT_REISSUE)
    if event == "PreToolUse":
        call = payload.get("toolCall")
        if isinstance(call, dict):
            name = first_string(call, ("name", "toolName", "tool_name"))
            args = call.get("args", call.get("arguments"))
        else:
            name = first_string(payload, ("tool_name", "toolName", "name"))
            args = payload.get("tool_input", payload.get("args"))
        if name in {"call_mcp_tool", "mcp_tool"} and isinstance(args, dict):
            normalised = _normalise_mcp_call(args)
            if normalised is None:
                return Extraction(record(payload, name))
            name, args = normalised
        return tool_call(payload, name, args)
    if event == "Stop":
        return assistant_reply(payload, payload.get("last_assistant_message"))
    return Extraction(record(payload))
