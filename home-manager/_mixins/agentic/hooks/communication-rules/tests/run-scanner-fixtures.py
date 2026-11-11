#!/usr/bin/env python3
"""Run the retained fixture corpus against the advisory contract.

Gate: checks.<system>.communication-rules-hooks runs this file through
lib/tests/communication-rules-hooks.nix. Historical fixture names remain so
that the transition does not discard the old failure cases.
"""

from __future__ import annotations

import json
import subprocess
import sys
import unittest

from advisory_support import (
    AGENTS,
    ROOT,
    RULES,
    AdvisoryCase,
    assert_no_permission,
    assert_record,
    invoke,
    wire,
)

FIXTURES = ROOT / "fixtures"


def event_name(agent, path, payload):
    if agent in ("claude-code", "codex"):
        return (
            payload.get("hook_event_name")
            or {
                "pre-tool-use": "PreToolUse",
                "user-prompt-submit": "UserPromptSubmit",
                "subagent-stop": "SubagentStop",
                "subagent-start": "SubagentStart",
                "session-start": "SessionStart",
                "stop-": "Stop",
            }[
                next(
                    prefix
                    for prefix in (
                        "pre-tool-use",
                        "user-prompt-submit",
                        "subagent-stop",
                        "subagent-start",
                        "session-start",
                        "stop-",
                    )
                    if path.stem.startswith(prefix)
                )
            ]
        )
    return payload.get("type") if agent == "pi" else payload.get("event")


class ScannerFixtures(AdvisoryCase):
    def test_native_fixture_corpus_has_no_permission_decisions(self):
        count = 0
        for agent in AGENTS:
            directory = FIXTURES / agent
            for path in sorted(directory.glob("*.json")):
                with self.subTest(agent=agent, fixture=path.name):
                    text = path.read_text().replace(
                        "__TRANSCRIPT_DIR__", str(directory)
                    )
                    payload = json.loads(text)
                    payload["session_id"] = f"fixture-{agent}-{path.stem}"
                    payload.setdefault("turn_id", "fixture-turn")
                    event = event_name(agent, path, payload)
                    decision = invoke(agent, event, payload)
                    assert_record(self, decision)
                    assert_no_permission(self, wire(agent, event, decision))
                    count += 1
        self.assertGreater(count, 80)
        print(f"native fixtures passed: {count}")

    def test_explicit_prose_lint_keeps_word_boundaries(self):
        count = 0
        for path in sorted(FIXTURES.glob("banned-word-*.md")):
            with self.subTest(fixture=path.name):
                expected = "pass" if "substring-pass" in path.name else "advisory"
                term = path.name.removeprefix("banned-word-").removesuffix(
                    "-boundary.md"
                )
                # Hyphenated words can be exact identifiers, so the lint skips them.
                if "-" in term:
                    expected = "pass"
                self.assert_lint(path.read_text(), expected)
                count += 1
        self.assertTrue(count)
        print(f"word boundary fixtures passed: {count}")

    def test_explicit_lint_preserves_fenced_and_quoted_evidence(self):
        count = 0
        for path in sorted(FIXTURES.glob("u201*.md")):
            with self.subTest(fixture=path.name):
                text = (
                    path.read_text()
                    .replace("\\u2014", chr(0x2014))
                    .replace("\\u2013", chr(0x2013))
                )
                expected = "advisory" if "prose-blocks" in path.name else "pass"
                self.assert_lint(text, expected)
                count += 1
        print(f"punctuation fixtures passed: {count}")

    def test_retained_shell_fixtures_never_signal_failure(self):
        count = 0
        for path in sorted(FIXTURES.glob("*.sh")):
            with self.subTest(fixture=path.name):
                completed = subprocess.run(
                    [
                        sys.executable,
                        str(ROOT / "scanner.py"),
                        "--rules",
                        str(RULES),
                        "scan-bash",
                    ],
                    input=path.read_text(),
                    text=True,
                    capture_output=True,
                    cwd=FIXTURES,
                    check=False,
                    timeout=10,
                )
                self.assertEqual(completed.returncode, 0, completed.stderr)
                self.assertIn(completed.stdout.strip(), ("pass", "advisory"))
                count += 1
        self.assertTrue(count)
        print(f"shell fixtures passed: {count}")

    def assert_lint(self, text, expected):
        completed = subprocess.run(
            [
                sys.executable,
                str(ROOT / "scanner.py"),
                "--rules",
                str(RULES),
                "scan-text",
            ],
            input=text,
            text=True,
            capture_output=True,
            check=False,
            timeout=10,
        )
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertEqual(completed.stdout.strip(), expected)


if __name__ == "__main__":
    unittest.main()
