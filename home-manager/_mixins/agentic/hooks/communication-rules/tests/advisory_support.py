"""Shared helpers for the gated advisory regression suites."""

from __future__ import annotations

import argparse
import copy
import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
from dataclasses import asdict
from pathlib import Path
from unittest.mock import patch

from skill_source import materialised_rules_path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from core import dispatch as dispatcher  # noqa: E402
from core.config import load_config  # noqa: E402

AGENTS = ("claude-code", "codex", "pi", "opencode")
RULES = materialised_rules_path()
CONFIG = load_config(argparse.Namespace(rules=str(RULES), policy_json=None))
BREACH = "Please " + "del" + "ve" + " into this."
TOOL_EVENTS = {
    "claude-code": "PreToolUse",
    "codex": "PreToolUse",
    "pi": "tool_call",
    "opencode": "tool.execute.before",
}
FINAL_EVENTS = {
    "claude-code": "Stop",
    "codex": "Stop",
    "pi": "message_end",
    "opencode": "message.final",
}


def tool_payload(agent, name, arguments, session="session", turn="turn-1"):
    payload = {"session_id": session, "turn_id": turn}
    if agent in ("claude-code", "codex"):
        payload.update(tool_name=name, tool_input=arguments)
    elif agent == "pi":
        payload.update(type="tool_call", toolName=name, input=arguments)
    else:
        payload.update(event="tool.execute.before", tool={"name": name}, args=arguments)
    return payload


def final_payload(agent, text=BREACH, session="session", turn="turn-1"):
    payload = {"session_id": session, "turn_id": turn}
    if agent in ("claude-code", "codex"):
        payload["last_assistant_message"] = text
    elif agent == "pi":
        payload.update(
            type="message_end",
            message={
                "role": "assistant",
                "content": [{"type": "text", "text": text}],
                "stopReason": "stop",
            },
        )
    else:
        payload.update(
            event="message.final",
            message={"role": "assistant", "content": text},
        )
    return payload


def publication(agent, session="session", turn="turn-1", body=BREACH):
    return tool_payload(
        agent,
        "mcp__github__create_issue",
        {"title": "Build status", "body": body, "owner": "example", "repo": "project"},
        session,
        turn,
    )


def invoke(agent, event, payload, config=CONFIG):
    before = copy.deepcopy(payload)
    with patch.object(sys, "stdin", io.StringIO(json.dumps(payload))):
        decision = dispatcher.dispatch(agent, event, config)
    if payload != before:
        raise AssertionError("The style check changed the event.")
    return decision


def wire(agent, event, decision, config=CONFIG):
    return dispatcher.shape_response(agent, event, decision, config)


def cli(agent, event, payload, state_dir, rules=RULES):
    return subprocess.run(
        [sys.executable, str(ROOT / "scanner.py"), "--rules", str(rules), agent, event],
        input=payload if isinstance(payload, str) else json.dumps(payload),
        capture_output=True,
        text=True,
        check=False,
        timeout=10,
        env={**os.environ, "COMMUNICATION_RULES_STATE_DIR": str(state_dir)},
    )


def assert_record(case, decision, expected=None):
    record = asdict(decision)
    case.assertEqual(
        set(record),
        {
            "decision",
            "surface",
            "level",
            "notice",
            "inject_base_rules",
            "append_correction",
        },
    )
    case.assertIn(record["decision"], ("pass", "advisory"))
    if expected is not None:
        case.assertEqual(record["decision"], expected, record)
    case.assertFalse(record["inject_base_rules"])
    case.assertFalse(record["append_correction"])
    case.assertLessEqual(len(record["notice"]), 320)
    case.assertNotIn("## The Cut Pass", record["notice"])
    if record["decision"] == "advisory":
        case.assertTrue(record["notice"], record)
    else:
        case.assertFalse(record["notice"], record)
    return record


def assert_no_permission(case, value):
    if isinstance(value, dict):
        forbidden = {
            "permissionDecision",
            "permissionDecisionReason",
            "permission",
            "updatedInput",
            "continue",
            "stopReason",
            "block",
            "blockReason",
            "tool_result",
            "replace",
            "allow",
            "deny",
        }
        case.assertFalse(set(value) & forbidden, value)
        if "decision" in value:
            case.assertIn(value["decision"], ("pass", "advisory"), value)
        for item in value.values():
            assert_no_permission(case, item)
    elif isinstance(value, list):
        for item in value:
            assert_no_permission(case, item)


class AdvisoryCase(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="communication-rules-test-")
        self.addCleanup(self.temp.cleanup)
        self.state_dir = Path(self.temp.name) / "state"
        self.environment = patch.dict(
            os.environ, {"COMMUNICATION_RULES_STATE_DIR": str(self.state_dir)}
        )
        self.environment.start()
        self.addCleanup(self.environment.stop)
