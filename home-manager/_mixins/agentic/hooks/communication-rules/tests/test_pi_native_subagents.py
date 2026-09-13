"""Check the native Pi delegation result names without changing report text."""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from core.extractors.pi import tool_result_text  # noqa: E402


class NativeSubagentResults(unittest.TestCase):
    def test_native_results_preserve_report_text(self):
        for name in ("Agent", "get_subagent_result", "SubagentWorkflow"):
            with self.subTest(tool=name):
                content = [{"type": "text", "text": "The tests pass."}]
                self.assertEqual(
                    tool_result_text({"toolName": name, "content": content}),
                    "The tests pass.",
                )
                self.assertEqual(
                    tool_result_text(
                        {"toolName": name, "result": {"content": content}}
                    ),
                    "The tests pass.",
                )
                self.assertIsNone(tool_result_text({"toolName": name}))

    def test_unrelated_results_remain_outside_the_report_scan(self):
        self.assertEqual(
            tool_result_text({"toolName": "read", "content": "File text"}), ""
        )


if __name__ == "__main__":
    unittest.main()
