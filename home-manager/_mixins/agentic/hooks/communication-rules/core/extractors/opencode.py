"""OpenCode extraction does not infer authorship from arbitrary text fields."""

from core.dispatch import EVENT_CONTEXT, EVENT_START, Extraction
from core.extractors import assistant_reply, first_string, record, tool_call


def extract(event: str, payload: dict, config=None) -> Extraction:
    if event in {"context", "turn-start"}:
        return Extraction(
            record(payload), EVENT_CONTEXT if event == "context" else EVENT_START
        )
    if event in {"tool-execute-before", "tool.execute.before"}:
        name = first_string(payload, ("toolName", "tool_name", "tool", "name"))
        if not name and isinstance(payload.get("tool"), dict):
            name = first_string(payload["tool"], ("name", "id"))
        return tool_call(payload, name, payload.get("args", payload.get("input")))
    if event in {"post-display", "message.final"}:
        message = payload.get("message")
        if (
            isinstance(message, dict)
            and message.get("role") == "assistant"
            and payload.get("surface") != "subagent"
        ):
            return assistant_reply(payload, message.get("content", message.get("text")))
    return Extraction(record(payload))
