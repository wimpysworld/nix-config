#!/usr/bin/env python3
"""Google Antigravity CLI command-hook shim for advisory Communication Rules."""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

MAX_INPUT = 1_000_000
NOTICE_LIMIT = 320


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run advisory Communication Rules checks for Antigravity hooks."
    )
    parser.add_argument("--scanner", default="")
    parser.add_argument("--policy-json", "--policy", dest="policy_json", default="")
    parser.add_argument("--rules", default="")
    parser.add_argument("event", nargs="?", default="")
    return parser.parse_args(argv)


def _conversation_id(payload: dict) -> str:
    for key in ("conversationId", "session_id", "sessionID", "sessionId"):
        value = payload.get(key)
        if isinstance(value, str) and value:
            return value
    return ""


def _queue_roots() -> list[Path]:
    explicit = os.environ.get("COMMUNICATION_RULES_STATE_DIR")
    if explicit:
        return [Path(explicit) / "antigravity-queue"]
    roots: list[Path] = []
    xdg_runtime = os.environ.get("XDG_RUNTIME_DIR")
    if xdg_runtime:
        roots.append(
            Path(xdg_runtime) / "agent-communication-rules" / "antigravity-queue"
        )
    xdg_cache = os.environ.get("XDG_CACHE_HOME")
    if xdg_cache:
        roots.append(
            Path(xdg_cache) / "agent-communication-rules" / "antigravity-queue"
        )
    roots.append(
        Path(tempfile.gettempdir())
        / f"agent-communication-rules-{os.getuid()}"
        / "antigravity-queue"
    )
    return roots


def _ensure_private_dir(directory: Path) -> bool:
    try:
        directory.mkdir(mode=0o700, parents=True, exist_ok=True)
        info = directory.lstat()
        return not directory.is_symlink() and info.st_uid == os.getuid()
    except OSError:
        return False


def _queue_notice(conversation_id: str, notice: str) -> None:
    cleaned = " ".join(notice.split())[:NOTICE_LIMIT]
    if not conversation_id or not cleaned:
        return
    key = hashlib.sha256(conversation_id.encode("utf-8")).hexdigest()
    for root in _queue_roots():
        if not _ensure_private_dir(root):
            continue
        stream = None
        try:
            stream = (root / f"{key}.json").open("a+", encoding="utf-8")
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
            stream.seek(0)
            raw = stream.read(4096)
            try:
                data = json.loads(raw) if raw else {}
            except (TypeError, ValueError):
                data = {}
            if not isinstance(data, dict):
                data = {}
            if not data.get("notice"):
                data["notice"] = cleaned
            stream.seek(0)
            stream.truncate()
            json.dump(data, stream)
            stream.flush()
            return
        except OSError:
            continue
        finally:
            if stream is not None:
                stream.close()


def _pop_queued_notice(conversation_id: str) -> str:
    if not conversation_id:
        return ""
    key = hashlib.sha256(conversation_id.encode("utf-8")).hexdigest()
    for root in _queue_roots():
        path = root / f"{key}.json"
        try:
            if not path.exists() or path.is_symlink():
                continue
        except OSError:
            continue
        stream = None
        try:
            stream = path.open("r+", encoding="utf-8")
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
            raw = stream.read(4096)
            try:
                data = json.loads(raw) if raw else {}
            except (TypeError, ValueError):
                data = {}
            notice = data.get("notice", "") if isinstance(data, dict) else ""
            stream.seek(0)
            stream.truncate()
            json.dump({}, stream)
            stream.flush()
            if isinstance(notice, str) and notice:
                return " ".join(notice.split())[:NOTICE_LIMIT]
        except OSError:
            continue
        finally:
            if stream is not None:
                stream.close()
    return ""


def _scanner_command(args: argparse.Namespace) -> list[str]:
    if args.scanner:
        cmd = [args.scanner]
    else:
        cmd = [sys.executable, str(Path(__file__).resolve().with_name("scanner.py"))]
    if args.policy_json:
        cmd.extend(["--policy-json", args.policy_json])
    if args.rules:
        cmd.extend(["--rules", args.rules])
    cmd.extend(["antigravity", args.event])
    return cmd


def _run_scanner(args: argparse.Namespace, raw_input: str) -> str:
    try:
        completed = subprocess.run(
            _scanner_command(args),
            input=raw_input,
            capture_output=True,
            text=True,
            check=False,
            timeout=3.0,
        )
    except (OSError, subprocess.SubprocessError):
        return ""
    if completed.returncode != 0 or not completed.stdout.strip():
        return ""
    try:
        decision = json.loads(completed.stdout)
    except ValueError:
        return ""
    if (
        isinstance(decision, dict)
        and decision.get("decision") == "advisory"
        and isinstance(decision.get("notice"), str)
    ):
        return " ".join(decision["notice"].split())[:NOTICE_LIMIT]
    return ""


def main(argv: list[str] | None = None) -> int:
    event = ""
    try:
        args = _parse_args(argv)
        event = args.event
        raw = sys.stdin.read(MAX_INPUT + 1)
        if len(raw) > MAX_INPUT:
            raw = ""
        try:
            parsed = json.loads(raw) if raw else {}
        except ValueError:
            parsed = {}
        payload = parsed if isinstance(parsed, dict) else {}
        conversation_id = _conversation_id(payload)

        if event == "PreToolUse":
            if raw and payload:
                notice = _run_scanner(args, raw)
                if notice:
                    _queue_notice(conversation_id, notice)
            print(json.dumps({"decision": "allow"}))
            return 0

        if event == "PreInvocation":
            queued = _pop_queued_notice(conversation_id)
            scanner_notice = _run_scanner(args, raw) if (raw and payload) else ""
            notice = queued or scanner_notice
            if notice:
                print(json.dumps({"injectSteps": [{"ephemeralMessage": notice}]}))
            else:
                print("{}")
            return 0

        print("{}")
        return 0
    except BaseException:
        if event == "PreToolUse":
            print(json.dumps({"decision": "allow"}))
        else:
            print("{}")
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
