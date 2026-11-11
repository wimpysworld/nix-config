"""Route known authored prose to advisory detection."""

from __future__ import annotations

import json
import sys
from dataclasses import asdict, dataclass

from core import responses, state
from core.config import Config
from core.detection import prose_findings
from core.types import Decision, ExtractorRecord

AGENTS = ("claude-code", "codex", "pi", "opencode")
EVENT_GATE = "gate"
EVENT_FACING = "facing"
EVENT_REISSUE = "reissue"
EVENT_CONTEXT = "context"
EVENT_REMINDER = "reminder"
EVENT_PASS = "pass"
EVENT_START = "turn-start"
SCAN_TEXT = "text"
SCAN_NONE = "none"


@dataclass
class Extraction:
    record: ExtractorRecord
    event_class: str = EVENT_PASS
    surface: str = "local"
    scan_mode: str = SCAN_NONE


def pass_decision() -> Decision:
    return Decision()


def decision_to_json(decision: Decision) -> str:
    return json.dumps(asdict(decision), sort_keys=True)


def read_event(stream=None) -> dict:
    try:
        raw = (stream or sys.stdin).read(1_000_001)
        if len(raw) > 1_000_000:
            return {}
        parsed = json.loads(raw)
        return parsed if isinstance(parsed, dict) else {}
    except (ValueError, OSError):
        return {}


def _extract(
    agent: str, event: str, payload: dict, config: Config | None
) -> Extraction:
    from core.extractors import claude_code, codex, opencode, pi

    extractor = {
        "claude-code": claude_code,
        "codex": codex,
        "opencode": opencode,
        "pi": pi,
    }[agent]
    return extractor.extract(event, payload, config)


def _run_scan(extraction: Extraction, config: Config) -> list[tuple[str, int]]:
    for text in extraction.record.texts:
        findings = prose_findings(text, config)
        if findings:
            return findings
    return []


def _decide(agent: str, extraction: Extraction, config: Config | None) -> Decision:
    record = extraction.record
    kind = extraction.event_class
    if kind == EVENT_PASS or kind == EVENT_REMINDER:
        return Decision()
    if kind == EVENT_START:
        return state.start_turn(agent, record)
    if kind == EVENT_REISSUE:
        state.start_turn(agent, record)
        return state.context(agent, record)
    if kind == EVENT_CONTEXT:
        return state.context(agent, record)
    if not record.texts:
        return Decision()
    if config is None:
        return state.advise(
            agent,
            record,
            "Communication Rules check unavailable. Continue without style feedback.",
        )
    findings = _run_scan(extraction, config)
    if findings:
        rule, line = findings[0]
        location = (record.target or record.tool or "reply")[:120]
        notice = f"Style advice: {rule} at {location}, line {line}. Preserve exact source text."
        return state.advise(
            agent,
            record,
            notice,
            "tierA" if kind == EVENT_FACING else "B2",
            pending=kind == EVENT_FACING,
        )
    return Decision()


def dispatch(agent: str, event: str, config: Config | None) -> Decision:
    payload = read_event()
    try:
        extraction = _extract(agent, event, payload, config)
        return _decide(agent, extraction, config)
    except Exception:
        record = ExtractorRecord(
            str(payload.get("session_id") or payload.get("sessionID") or ""),
            payload.get("turn_id"),
            event,
            None,
            [],
        )
        try:
            return state.advise(
                agent,
                record,
                "Communication Rules check unavailable. Continue without style feedback.",
            )
        except Exception:
            return Decision()


def shape_response(
    agent: str, event: str, decision: Decision, config=None
) -> dict | None:
    if agent in {"claude-code", "codex"}:
        return responses.command_response(event, decision)
    return responses.plugin_response(decision)
