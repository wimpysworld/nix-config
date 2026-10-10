#!/usr/bin/env python3
"""Check that Pi posts through every MCP call form reach the scanner.

pi-mcp-adapter names tools without the `mcp__` marker, so a matcher that keys on
that marker alone lets adapter posts through unchecked. Each case spawns
`scanner.py pi tool_call` against a temporary agent directory holding the
adapter config, so the result does not depend on the real home directory.

Stdlib only. The breach body reads its banned term from the policy, so this
file holds no literal banned word.

Gate: ``checks.<system>.communication-rules-hooks``, defined in
``lib/tests/communication-rules-hooks.nix``, runs this file.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from skill_source import materialised_rules_path

ROOT = Path(__file__).resolve().parents[1]
SCANNER = ROOT / "scanner.py"
RULES = materialised_rules_path()

sys.path.insert(0, str(ROOT))
from core.config import DEFAULT_POLICY  # noqa: E402

BREACH = f"Please {DEFAULT_POLICY['hardGateBannedTerms'][0]} this."

# Post forms: tool name and input. Every one carries the breach body.
POSTS = {
    "direct": ("linear_save_comment", {"issueId": "A-1", "body": BREACH}),
    "direct short prefix": ("trace_send_note", {"text": BREACH}),
    "direct mcp prefix": (
        "mcp__linear_save_comment",
        {"issueId": "A-1", "body": BREACH},
    ),
    "gateway prefixed": (
        "mcp",
        {"tool": "slack_send_message", "args": {"text": BREACH}},
    ),
    "gateway original name": (
        "mcp",
        {"tool": "save_comment", "server": "linear", "args": {"body": BREACH}},
    ),
    "gateway JSON string args": (
        "mcp",
        {"tool": "linear_save_comment", "args": json.dumps({"body": BREACH})},
    ),
    "namespace proxy": (
        "mcp__linear",
        {"tool": "save_comment", "args": {"body": BREACH}},
    ),
    "claude code form": (
        "mcp__linear__save_comment",
        {"issueId": "A-1", "body": BREACH},
    ),
}

# Read-only and non-MCP calls, including ones whose server or argument text
# carries a post term. None of them may be blocked.
READS = {
    "direct read": ("linear_get_issue", {"id": "A-1"}),
    "server name with post term": ("post-office_get_letter", {"id": "1"}),
    "gateway read": ("mcp", {"tool": "linear_get_issue", "args": {"id": "A-1"}}),
    "gateway search": ("mcp", {"search": "send message"}),
    "namespace proxy read": (
        "mcp__slack",
        {"tool": "read_channel", "args": {"channel": "C1"}},
    ),
    "non-MCP tool": ("todo_write", {"text": BREACH}),
    "script read": (
        "mcpScript",
        {"code": "emit(await tools.call('linear_get_issue', {id: 'A-1'}))"},
    ),
}


class PiMcpAdapterPosts(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.temp = tempfile.TemporaryDirectory(prefix="tripwire-pi-mcp-")
        agent_dir = Path(cls.temp.name) / "agent"
        agent_dir.mkdir()
        servers = {"linear": {}, "slack": {}, "trace-mcp": {}, "post-office": {}}
        (agent_dir / "mcp-adapter.json").write_text(json.dumps({"mcpServers": servers}))
        cls.env = {
            **os.environ,
            "PI_CODING_AGENT_DIR": str(agent_dir),
            "TRIPWIRE_PI_STRIKE_DIR": str(Path(cls.temp.name) / "strikes"),
            "TRIPWIRE_PI_REISSUE_DIR": str(Path(cls.temp.name) / "reissue"),
        }

    @classmethod
    def tearDownClass(cls) -> None:
        cls.temp.cleanup()

    def decide(self, label: str, name: str, input_value: dict) -> str:
        payload = {
            "session_id": f"pi-mcp-{label}",
            "type": "tool_call",
            "toolName": name,
            "toolCallId": f"call-{label}",
            "input": input_value,
        }
        completed = subprocess.run(
            [sys.executable, str(SCANNER), "--rules", str(RULES), "pi", "tool_call"],
            input=json.dumps(payload),
            capture_output=True,
            text=True,
            env=self.env,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stderr)
        return json.loads(completed.stdout)["decision"]

    def test_posts_through_every_mcp_form_are_checked(self):
        for label, (name, input_value) in POSTS.items():
            with self.subTest(form=label):
                self.assertEqual(self.decide(label, name, input_value), "block")

    def test_read_only_calls_pass(self):
        for label, (name, input_value) in READS.items():
            with self.subTest(form=label):
                self.assertEqual(self.decide(label, name, input_value), "pass")

    def test_script_naming_a_post_fails_closed(self):
        code = "await tools.call('linear_save_comment', {issueId: 'A-1', body: 'ok'})"
        self.assertEqual(
            self.decide("script-post", "mcpScript", {"code": code}), "block"
        )


if __name__ == "__main__":
    unittest.main()
