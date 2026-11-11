"""Positive operation classification shared by the native extractors."""

from __future__ import annotations

from core.detection import publication_command_texts
from core.dispatch import EVENT_FACING, EVENT_GATE, SCAN_TEXT, Extraction
from core.types import ExtractorRecord

# Exact operations whose text fields represent a publication draft.
PUBLICATIONS = {
    "add_comment",
    "create_comment",
    "post_comment",
    "reply_to_comment",
    "save_comment",
    "create_issue",
    "update_issue",
    "save_issue",
    "create_pull_request",
    "update_pull_request",
    "create_review",
    "submit_review",
    "send_message",
    "post_message",
    "chat_postmessage",
    "chat_update",
    "create_document",
    "update_document",
    "save_document",
    "save_project",
    "save_initiative",
    "save_milestone",
    "save_release",
    "publish_post",
    "create_post",
    "update_post",
}
PROSE_FIELDS = (
    "body",
    "comment",
    "description",
    "message",
    "text",
    "title",
    "summary",
    "content",
)
READ_VERBS = {
    "get",
    "list",
    "read",
    "search",
    "fetch",
    "view",
    "show",
    "find",
    "query",
    "retrieve",
    "inspect",
    "count",
}


def first_string(data: dict, keys) -> str:
    for key in keys:
        value = data.get(key)
        if isinstance(value, str) and value:
            return value
    return ""


def record(payload: dict, tool: str = "", target: str | None = None) -> ExtractorRecord:
    session = first_string(payload, ("session_id", "sessionID", "sessionId"))
    turn = first_string(payload, ("turn_id", "turnID", "turnId")) or None
    return ExtractorRecord(session, turn, tool, target, [])


def text_blocks(value) -> list[str]:
    if isinstance(value, str):
        return [value]
    if isinstance(value, list):
        return [
            item["text"]
            for item in value
            if isinstance(item, dict)
            and item.get("type") == "text"
            and isinstance(item.get("text"), str)
        ]
    return []


def leaf_name(name: str) -> str:
    leaf = name.rsplit("__", 1)[-1].replace("-", "_").replace(".", "_").lower()
    for prefix in ("linear_", "slack_", "github_"):
        if leaf.startswith(prefix):
            return leaf[len(prefix) :]
    return leaf


def publication(name: str, args: dict) -> bool:
    leaf = leaf_name(name)
    if leaf.split("_", 1)[0] in READ_VERBS:
        return False
    method = args.get("method") or args.get("operation") or args.get("action")
    if isinstance(method, str):
        leaf = leaf_name(method)
        if leaf.split("_", 1)[0] in READ_VERBS:
            return False
    return leaf in PUBLICATIONS


def tool_call(payload: dict, name: str, args) -> Extraction:
    rec = record(payload, name)
    result = Extraction(rec)
    if not isinstance(args, dict):
        return result
    if name in {"mcp", "mcp__linear", "mcp__slack", "mcp__github"}:
        nested_name = args.get("tool")
        nested_args = args.get("args")
        if isinstance(nested_name, str) and isinstance(nested_args, dict):
            return tool_call(payload, nested_name, nested_args)
    leaf = leaf_name(name)
    if leaf in {"bash", "exec_command", "shell"}:
        command = first_string(args, ("command", "cmd"))
        rec.texts = publication_command_texts(command)
    elif publication(name, args):
        rec.texts = [
            args[key] for key in PROSE_FIELDS if isinstance(args.get(key), str)
        ]
    # Local file content and source programs have no reliable provenance.
    if rec.texts:
        rec.target = name
        return Extraction(rec, EVENT_GATE, "external", SCAN_TEXT)
    return result


def assistant_reply(payload: dict, value, *, tool: str = "reply") -> Extraction:
    rec = record(payload, tool)
    rec.texts = text_blocks(value)
    return (
        Extraction(rec, EVENT_FACING, scan_mode=SCAN_TEXT)
        if rec.texts
        else Extraction(rec)
    )
