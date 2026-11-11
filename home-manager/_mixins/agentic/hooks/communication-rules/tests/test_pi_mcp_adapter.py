#!/usr/bin/env python3
"""Check Pi publication aliases and read-only MCP calls.

Gate: checks.<system>.communication-rules-hooks runs this file through
lib/tests/communication-rules-hooks.nix. Calls use native argument shapes.
"""

from __future__ import annotations

import unittest
from unittest.mock import patch

from advisory_support import (
    BREACH,
    AdvisoryCase,
    assert_no_permission,
    assert_record,
    dispatcher,
    invoke,
    tool_payload,
    wire,
)

POSTS = {
    "direct": ("linear_save_comment", {"issueId": "A-1", "body": BREACH}),
    "native": ("mcp__linear__create_comment", {"issueId": "A-1", "body": BREACH}),
    "gateway prefixed": (
        "mcp",
        {"tool": "slack_send_message", "args": {"text": BREACH}},
    ),
    "gateway original name": (
        "mcp",
        {"tool": "save_comment", "server": "linear", "args": {"body": BREACH}},
    ),
    "namespace proxy": (
        "mcp__linear",
        {"tool": "save_comment", "args": {"body": BREACH}},
    ),
}

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
    "review read with text filter": (
        "github_get_review",
        {"id": "review-1", "text": BREACH},
    ),
}


class PiMcpAdapter(AdvisoryCase):
    def test_recognised_publications_only_return_advice(self):
        for label, (name, arguments) in POSTS.items():
            with self.subTest(form=label):
                payload = tool_payload("pi", name, arguments, session=label)
                decision = invoke("pi", "tool_call", payload)
                assert_record(self, decision, "advisory")
                assert_no_permission(self, wire("pi", "tool_call", decision))

    def test_read_only_calls_never_reach_the_scanner(self):
        for label, (name, arguments) in READS.items():
            with self.subTest(form=label):
                payload = tool_payload("pi", name, arguments, session=label)
                with patch.object(dispatcher, "_run_scan") as scanner:
                    assert_record(self, invoke("pi", "tool_call", payload), "pass")
                    scanner.assert_not_called()

    def test_script_sources_and_unknown_tools_do_not_infer_authorship(self):
        cases = (
            (
                "mcpScript",
                {
                    "code": "await tools.call('linear_save_comment', {body: '"
                    + BREACH
                    + "'})"
                },
            ),
            ("trace_send_note", {"text": BREACH}),
            (
                "mcp",
                {"tool": "linear_save_comment", "args": '{"body": "Exact source"}'},
            ),
        )
        for name, arguments in cases:
            with self.subTest(tool=name):
                payload = tool_payload("pi", name, arguments)
                with patch.object(dispatcher, "_run_scan") as scanner:
                    assert_record(self, invoke("pi", "tool_call", payload), "pass")
                    scanner.assert_not_called()


if __name__ == "__main__":
    unittest.main()
