"""Native advisory responses leave permission decisions untouched."""

from dataclasses import asdict

from core.types import Decision


def command_response(event: str, decision: Decision) -> dict | None:
    if decision.decision != "advisory" or not decision.notice:
        return None
    if event in {"Stop", "SubagentStop"}:
        return {"systemMessage": decision.notice}
    return {
        "hookSpecificOutput": {
            "hookEventName": event,
            "additionalContext": decision.notice,
        }
    }


def plugin_response(decision: Decision, *unused: str) -> dict:
    return asdict(decision)
