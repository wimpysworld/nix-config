"""Pi input extraction, restricted to current assistant prose and publication."""

from core.dispatch import EVENT_CONTEXT, EVENT_START, Extraction
from core.extractors import assistant_reply, first_string, record, tool_call


def extract(event: str, payload: dict, config=None) -> Extraction:
    if event in {"context", "turn-start"}:
        return Extraction(
            record(payload), EVENT_CONTEXT if event == "context" else EVENT_START
        )
    inner = payload
    for key in ("event", "payload"):
        if isinstance(payload.get(key), dict):
            inner = {**payload[key]}
            for identity in ("session_id", "turn_id"):
                if identity in payload:
                    inner[identity] = payload[identity]
            break
    if event == "tool_call":
        return tool_call(
            inner,
            first_string(inner, ("toolName", "tool_name", "name", "tool")),
            inner.get("input", inner.get("args")),
        )
    if event == "message_end":
        message = inner.get("message")
        if (
            isinstance(message, dict)
            and message.get("role") == "assistant"
            and message.get("stopReason") != "toolUse"
        ):
            return assistant_reply(inner, message.get("content"))
    return Extraction(record(inner))
