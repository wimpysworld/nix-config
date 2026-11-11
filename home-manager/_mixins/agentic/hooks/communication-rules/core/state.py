"""Bounded advisory notices, deduplicated by session and user turn."""

from __future__ import annotations

import fcntl
import hashlib
import json
import os
import uuid
from contextlib import contextmanager
from pathlib import Path

from core.types import Decision, ExtractorRecord

NOTICE_LIMIT = 320


@contextmanager
def _session_state(agent: str, session: str):
    if not session:
        yield None
        return
    root = Path(
        os.environ.get("COMMUNICATION_RULES_STATE_DIR")
        or os.path.join(
            os.environ.get("XDG_RUNTIME_DIR") or os.environ.get("TMPDIR") or "/tmp",
            "agent-communication-rules",
            "advisory",
        )
    )
    key = hashlib.sha256(f"{agent}\0{session}".encode()).hexdigest()
    try:
        root.mkdir(mode=0o700, parents=True, exist_ok=True)
        stream = (root / f"{key}.json").open("a+", encoding="utf-8")
        fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        if "stream" in locals():
            stream.close()
        yield None
        return
    try:
        stream.seek(0)
        raw = stream.read(4096)
        try:
            data = json.loads(raw) if raw else {}
        except (ValueError, TypeError):
            data = {}
        if not isinstance(data, dict):
            data = {}
        yield data
        stream.seek(0)
        stream.truncate()
        json.dump(data, stream)
        stream.flush()
    finally:
        stream.close()


def _turn(data: dict, turn: str | None) -> None:
    if turn and data.get("turn") != turn:
        data["turn"] = turn
        data["notified"] = False


def start_turn(agent: str, record: ExtractorRecord) -> Decision:
    try:
        with _session_state(agent, record.session) as data:
            if data is not None:
                _turn(data, record.turn or uuid.uuid4().hex)
    except OSError:
        pass
    return Decision()


def advise(
    agent: str,
    record: ExtractorRecord,
    notice: str,
    surface: str = "tierA",
    *,
    pending: bool = False,
) -> Decision:
    notice = " ".join(notice.split())[:NOTICE_LIMIT]
    if not notice:
        return Decision()
    try:
        with _session_state(agent, record.session) as data:
            if data is None:
                return Decision()
            _turn(data, record.turn)
            if data.get("notified"):
                return Decision()
            data["notified"] = True
            if pending:
                data["pending"] = notice
        return Decision("advisory", surface, notice)
    except OSError:
        return Decision()


def context(agent: str, record: ExtractorRecord) -> Decision:
    try:
        with _session_state(agent, record.session) as data:
            if data is None:
                return Decision()
            _turn(data, record.turn)
            if data.get("notified"):
                return Decision()
            notice = data.pop("pending", "")
            if not isinstance(notice, str) or not notice:
                return Decision()
            data["notified"] = True
        return Decision("advisory", notice=notice[:NOTICE_LIMIT])
    except OSError:
        return Decision()
