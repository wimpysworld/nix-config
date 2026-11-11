"""Claude Code input extraction without transcript or incoming-result scans."""

from core.dispatch import EVENT_REISSUE, Extraction
from core.extractors import assistant_reply, record, tool_call


def extract(event: str, payload: dict, config=None) -> Extraction:
    if event == "PreToolUse":
        return tool_call(
            payload, str(payload.get("tool_name", "")), payload.get("tool_input")
        )
    if event == "Stop":
        return assistant_reply(payload, payload.get("last_assistant_message"))
    if event == "UserPromptSubmit":
        return Extraction(record(payload), EVENT_REISSUE)
    return Extraction(record(payload))
