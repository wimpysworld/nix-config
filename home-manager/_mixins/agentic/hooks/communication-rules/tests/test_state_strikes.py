#!/usr/bin/env python3
"""Check bounded notices in place of the former strike policy.

Gate: checks.<system>.communication-rules-hooks runs this suite through
lib/tests/communication-rules-hooks.nix.
"""

from __future__ import annotations

import json
import unittest

from advisory_support import (
    AGENTS,
    BREACH,
    TOOL_EVENTS,
    AdvisoryCase,
    assert_no_permission,
    assert_record,
    cli,
    invoke,
    publication,
    tool_payload,
    wire,
)
from core import state
from core.types import ExtractorRecord


class BoundedNotices(AdvisoryCase):
    def test_repeated_publications_with_interleaved_reads_never_gate(self):
        for agent in AGENTS:
            with self.subTest(agent=agent):
                payload = publication(agent, session=f"retry-{agent}")
                first = invoke(agent, TOOL_EVENTS[agent], payload)
                assert_record(self, first, "advisory")
                self.assertIn("line", first.notice)
                self.assertIn("create_issue", first.notice)
                assert_no_permission(self, wire(agent, TOOL_EVENTS[agent], first))
                for _ in range(7):
                    read = tool_payload(
                        agent,
                        "mcp__github__get_pull_request_review",
                        {"id": "review-42"},
                        session=f"retry-{agent}",
                    )
                    assert_record(self, invoke(agent, TOOL_EVENTS[agent], read), "pass")
                    repeated = invoke(agent, TOOL_EVENTS[agent], payload)
                    assert_record(self, repeated, "pass")
                    assert_no_permission(
                        self, wire(agent, TOOL_EVENTS[agent], repeated)
                    )

    def test_one_notice_covers_different_tools_and_targets_in_one_turn(self):
        for agent in AGENTS:
            with self.subTest(agent=agent):
                session = f"targets-{agent}"
                first = publication(agent, session=session)
                second = tool_payload(
                    agent,
                    "mcp__linear__create_comment",
                    {"issueId": "ENG-2", "body": BREACH},
                    session=session,
                )
                assert_record(
                    self, invoke(agent, TOOL_EVENTS[agent], first), "advisory"
                )
                assert_record(self, invoke(agent, TOOL_EVENTS[agent], second), "pass")

    def test_new_turn_resets_budget_without_affecting_another_session(self):
        for agent in AGENTS:
            with self.subTest(agent=agent):
                record = ExtractorRecord("turn-session", "one", "post", "issue", [])
                state.start_turn(agent, record)
                assert_record(
                    self, state.advise(agent, record, "Use plain words."), "advisory"
                )
                assert_record(
                    self, state.advise(agent, record, "Use plain words."), "pass"
                )
                other = ExtractorRecord("other-session", "one", "post", "issue", [])
                assert_record(
                    self, state.advise(agent, other, "Use plain words."), "advisory"
                )
                next_turn = ExtractorRecord("turn-session", "two", "post", "issue", [])
                state.start_turn(agent, next_turn)
                assert_record(
                    self, state.advise(agent, next_turn, "Use plain words."), "advisory"
                )

    def test_dedupe_survives_scanner_process_boundaries(self):
        for agent in AGENTS:
            with self.subTest(agent=agent):
                payload = publication(agent, session=f"process-{agent}")
                outputs = [
                    cli(agent, TOOL_EVENTS[agent], payload, self.state_dir)
                    for _ in range(3)
                ]
                for completed in outputs:
                    self.assertEqual(completed.returncode, 0, completed.stderr)
                    value = (
                        json.loads(completed.stdout)
                        if completed.stdout.strip()
                        else None
                    )
                    assert_no_permission(self, value)
                if agent in ("pi", "opencode"):
                    self.assertEqual(
                        json.loads(outputs[0].stdout)["decision"], "advisory"
                    )
                    self.assertTrue(
                        all(
                            json.loads(item.stdout)["decision"] == "pass"
                            for item in outputs[1:]
                        )
                    )
                else:
                    self.assertTrue(outputs[0].stdout.strip())
                    self.assertTrue(
                        all(not item.stdout.strip() for item in outputs[1:])
                    )

    def test_missing_session_suppresses_feedback_instead_of_sharing_state(self):
        for agent in AGENTS:
            record = ExtractorRecord("", "turn", "post", "issue", [])
            assert_record(self, state.advise(agent, record, "Use plain words."), "pass")


if __name__ == "__main__":
    unittest.main()
