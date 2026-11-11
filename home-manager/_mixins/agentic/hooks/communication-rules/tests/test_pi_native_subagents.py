"""Check that imported Pi reports remain outside the style scan.

Gate: checks.<system>.communication-rules-hooks runs this file through
lib/tests/communication-rules-hooks.nix.
"""

import unittest
from unittest.mock import patch

from advisory_support import BREACH, AdvisoryCase, assert_record, dispatcher, invoke
from core import state
from core.types import ExtractorRecord


class NativeSubagentResults(AdvisoryCase):
    def test_native_results_preserve_report_text_without_scanning(self):
        for name in ("Agent", "get_subagent_result", "SubagentWorkflow"):
            for result in (
                {"content": [{"type": "text", "text": BREACH}]},
                {"result": {"content": [{"type": "text", "text": BREACH}]}},
                {},
            ):
                with self.subTest(tool=name, result=result):
                    payload = {"session_id": name, "toolName": name, **result}
                    with patch.object(dispatcher, "_run_scan") as scanner:
                        assert_record(
                            self, invoke("pi", "tool_result", payload), "pass"
                        )
                        scanner.assert_not_called()
                    record = ExtractorRecord(name, "next", "", None, [])
                    state.start_turn("pi", record)
                    assert_record(self, state.context("pi", record), "pass")

    def test_unrelated_results_remain_outside_the_report_scan(self):
        payload = {"session_id": "read", "toolName": "read", "content": BREACH}
        with patch.object(dispatcher, "_run_scan") as scanner:
            assert_record(self, invoke("pi", "tool_result", payload), "pass")
            scanner.assert_not_called()


if __name__ == "__main__":
    unittest.main()
