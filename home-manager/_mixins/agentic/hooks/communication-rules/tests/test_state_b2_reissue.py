#!/usr/bin/env python3
"""Check one pending advisory in place of strike escalation and correction.

Gate: checks.<system>.communication-rules-hooks runs this suite through
lib/tests/communication-rules-hooks.nix.
"""

from __future__ import annotations

import unittest

from advisory_support import (
    AGENTS,
    FINAL_EVENTS,
    AdvisoryCase,
    assert_no_permission,
    assert_record,
    final_payload,
    invoke,
    wire,
)
from core import state
from core.types import ExtractorRecord


class PendingContext(AdvisoryCase):
    def test_pending_notice_is_consumed_once_after_normal_turn_start(self):
        for agent in AGENTS:
            with self.subTest(agent=agent):
                first = ExtractorRecord(f"pending-{agent}", "one", "", None, [])
                assert_record(
                    self,
                    state.advise(agent, first, "Use plain words.", pending=True),
                    "advisory",
                )
                next_turn = ExtractorRecord(f"pending-{agent}", "two", "", None, [])
                state.start_turn(agent, next_turn)
                notice = state.context(agent, next_turn)
                assert_record(self, notice, "advisory")
                assert_record(self, state.context(agent, next_turn), "pass")
                assert_record(
                    self,
                    state.advise(agent, next_turn, "Use plain words."),
                    "pass",
                )

    def test_multiple_findings_keep_only_one_pending_notice(self):
        for agent in AGENTS:
            record = ExtractorRecord(f"one-pending-{agent}", "one", "", None, [])
            for _ in range(6):
                state.advise(agent, record, "Use plain words.", pending=True)
            next_turn = ExtractorRecord(f"one-pending-{agent}", "two", "", None, [])
            state.start_turn(agent, next_turn)
            assert_record(self, state.context(agent, next_turn), "advisory")
            assert_record(self, state.context(agent, next_turn), "pass")
            files = list(self.state_dir.glob("*.json"))
            self.assertLessEqual(len(files), len(AGENTS))

    def test_current_final_is_not_rewritten_and_never_blocks_stop(self):
        for agent in AGENTS:
            with self.subTest(agent=agent):
                payload = final_payload(agent, session=f"final-{agent}")
                decision = invoke(agent, FINAL_EVENTS[agent], payload)
                assert_record(self, decision, "advisory")
                response = wire(agent, FINAL_EVENTS[agent], decision)
                assert_no_permission(self, response)
                if agent in ("claude-code", "codex"):
                    self.assertEqual(set(response), {"systemMessage"})

    def test_imported_subagent_reports_do_not_create_pending_feedback(self):
        for agent in AGENTS:
            with self.subTest(agent=agent):
                session = f"import-{agent}"
                if agent in ("claude-code", "codex"):
                    event = "SubagentStop"
                    payload = final_payload(agent, session=session)
                elif agent == "pi":
                    event = "tool_result"
                    payload = {
                        "session_id": session,
                        "toolName": "Agent",
                        "content": [
                            {
                                "type": "text",
                                "text": "Please " + "del" + "ve" + " into this.",
                            }
                        ],
                    }
                else:
                    event = "subagent.final"
                    payload = final_payload(agent, session=session)
                assert_record(self, invoke(agent, event, payload), "pass")
                record = ExtractorRecord(session, "next", "", None, [])
                state.start_turn(agent, record)
                assert_record(self, state.context(agent, record), "pass")


if __name__ == "__main__":
    unittest.main()
