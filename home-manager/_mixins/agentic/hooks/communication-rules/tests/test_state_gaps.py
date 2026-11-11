#!/usr/bin/env python3
"""Check read isolation, preserved material and fail-open boundaries.

Gate: checks.<system>.communication-rules-hooks runs this suite through
lib/tests/communication-rules-hooks.nix.
"""

from __future__ import annotations

import fcntl
import json
import unittest
from unittest.mock import patch

from advisory_support import (
    AGENTS,
    BREACH,
    FINAL_EVENTS,
    ROOT,
    TOOL_EVENTS,
    AdvisoryCase,
    assert_no_permission,
    assert_record,
    cli,
    dispatcher,
    final_payload,
    invoke,
    publication,
    tool_payload,
    wire,
)
from core import state
from core.types import ExtractorRecord


class ReadIsolation(AdvisoryCase):
    def test_read_method_overrides_a_publication_tool_name(self):
        for agent in AGENTS:
            payload = publication(agent)
            arguments = payload.get(
                "tool_input", payload.get("input", payload.get("args"))
            )
            arguments["method"] = "get"
            with patch.object(dispatcher, "_run_scan") as scanner:
                assert_record(self, invoke(agent, TOOL_EVENTS[agent], payload), "pass")
                scanner.assert_not_called()

    def test_read_search_comment_review_and_identifier_fields_never_reach_scanner(self):
        names = (
            "mcp__github__get_pull_request_review",
            "mcp__github__list_review_comments",
            "mcp__github__read_comment",
            "mcp__github__search_issues",
            "mcp__linear__get_issue",
        )
        for agent in AGENTS:
            for name in names:
                with self.subTest(agent=agent, tool=name):
                    payload = tool_payload(
                        agent,
                        name,
                        {"id": "review-42", "text": BREACH, "filter": BREACH},
                    )
                    with patch.object(dispatcher, "_run_scan") as scanner:
                        assert_record(
                            self, invoke(agent, TOOL_EVENTS[agent], payload), "pass"
                        )
                        scanner.assert_not_called()

    def test_observed_shell_reads_never_reach_scanner(self):
        commands = (
            "gh pr view 42 -t '{{.body}}'",
            "gh pr view 42 --template '{{.body}}'",
            "gh-api-safe graphql -f query='query { search(query: \"mutation createIssue\", type: ISSUE) { issueCount } }'",
            "rg '" + "del" + "ve" + "' README.md",
            "python -c 'print(\"read comment\")'",
        )
        for agent in AGENTS:
            for command in commands:
                with self.subTest(agent=agent, command=command):
                    payload = tool_payload(
                        agent,
                        "Bash" if agent in ("claude-code", "codex") else "bash",
                        {"command": command},
                    )
                    with patch.object(dispatcher, "_run_scan") as scanner:
                        assert_record(
                            self, invoke(agent, TOOL_EVENTS[agent], payload), "pass"
                        )
                        scanner.assert_not_called()

    def test_codex_nested_code_mode_read_calls_never_reach_scanner(self):
        sources = (
            "text(await tools.mcp__github__get_pull_request_review({id: 'review-42'}));",
            "text(await tools.mcp__github__list_review_comments({id: 'review-42', filter: '"
            + BREACH
            + "'}));",
            "text(await tools.exec_command({cmd: \"gh pr view 42 -t '{{.body}}'\"}));",
        )
        for source in sources:
            with self.subTest(source=source):
                payload = tool_payload("codex", "functions.exec", source)
                with patch.object(dispatcher, "_run_scan") as scanner:
                    assert_record(self, invoke("codex", "PreToolUse", payload), "pass")
                    scanner.assert_not_called()

    def test_unknown_local_files_and_imported_assets_never_reach_scanner(self):
        for agent in AGENTS:
            for filename in ("notes.md", "LICENSE", "source.py", "template.md"):
                for name, arguments in (
                    ("Write", {"file_path": filename, "content": BREACH}),
                    ("Edit", {"file_path": filename, "new_string": BREACH}),
                    (
                        "apply_patch",
                        {
                            "patch": "*** Begin Patch\n*** Add File: "
                            + filename
                            + "\n+"
                            + BREACH
                            + "\n*** End Patch"
                        },
                    ),
                ):
                    with self.subTest(agent=agent, file=filename, tool=name):
                        if agent in ("pi", "opencode"):
                            name = name.lower()
                        payload = tool_payload(agent, name, arguments)
                        with patch.object(dispatcher, "_run_scan") as scanner:
                            assert_record(
                                self, invoke(agent, TOOL_EVENTS[agent], payload), "pass"
                            )
                            scanner.assert_not_called()

    def test_incoming_tool_results_and_non_assistant_messages_are_not_scanned(self):
        for agent in AGENTS:
            events = ("PostToolUse", "tool_result", "subagent.final")
            for event in events:
                payload = tool_payload(agent, "Agent", {"text": BREACH})
                payload.update(
                    content=[{"type": "text", "text": BREACH}], toolName="Agent"
                )
                with self.subTest(agent=agent, event=event):
                    with patch.object(dispatcher, "_run_scan") as scanner:
                        assert_record(self, invoke(agent, event, payload), "pass")
                        scanner.assert_not_called()
        for agent in ("pi", "opencode"):
            for role in ("user", "tool", "system"):
                payload = final_payload(agent)
                payload["message"]["role"] = role
                with patch.object(dispatcher, "_run_scan") as scanner:
                    assert_record(
                        self, invoke(agent, FINAL_EVENTS[agent], payload), "pass"
                    )
                    scanner.assert_not_called()


class PreservedContent(AdvisoryCase):
    def test_preserved_content_does_not_create_advice_or_change_text(self):
        term = "del" + "ve"
        texts = (
            "> " + BREACH,
            '"' + BREACH + '"',
            "`" + term + "`",
            "https://example.org/" + term,
            "The identifier is `" + term + "_value`.",
            term + "_value",
            "const " + term + " = 1",
            "Copyright 2026 Example\n" + BREACH,
            "SPDX-License-Identifier: MIT\n" + BREACH,
            "\n\n```python\n" + term + " = 1\n```",
        )
        for agent in AGENTS:
            for index, text in enumerate(texts):
                with self.subTest(agent=agent, evidence=index):
                    payload = final_payload(
                        agent, text, session=f"evidence-{agent}-{index}"
                    )
                    assert_record(
                        self, invoke(agent, FINAL_EVENTS[agent], payload), "pass"
                    )

    def test_publication_body_is_advisory_without_changing_authority_or_payload(self):
        for agent in AGENTS:
            payload = publication(agent, session=f"security-{agent}")
            payload["permission_mode"] = "never"
            decision = invoke(agent, TOOL_EVENTS[agent], payload)
            assert_record(self, decision, "advisory")
            assert_no_permission(self, wire(agent, TOOL_EVENTS[agent], decision))
            self.assertEqual(payload["permission_mode"], "never")


class FailOpen(AdvisoryCase):
    def test_scanner_exceptions_do_not_reject_tools(self):
        for agent in AGENTS:
            with self.subTest(agent=agent):
                with patch.object(
                    dispatcher,
                    "_run_scan",
                    side_effect=RuntimeError("checker unavailable"),
                ):
                    decision = invoke(agent, TOOL_EVENTS[agent], publication(agent))
                assert_record(self, decision)
                assert_no_permission(self, wire(agent, TOOL_EVENTS[agent], decision))

    def test_missing_configuration_and_unresolved_bodies_do_not_reject_tools(self):
        for agent in AGENTS:
            for payload in (
                publication(agent),
                tool_payload(agent, "mcp__github__create_issue", {"labels": ["bug"]}),
            ):
                with self.subTest(agent=agent, payload=payload):
                    with patch.object(dispatcher, "_run_scan") as scanner:
                        decision = invoke(
                            agent, TOOL_EVENTS[agent], payload, config=None
                        )
                        scanner.assert_not_called()
                    assert_record(self, decision)
                    assert_no_permission(
                        self, wire(agent, TOOL_EVENTS[agent], decision, config=None)
                    )

    def test_invalid_input_json_and_missing_rules_fail_open_at_cli_boundary(self):
        for agent in AGENTS:
            for body, rules in (
                ("{", ROOT / "missing-rules.md"),
                (publication(agent), ROOT / "missing-rules.md"),
            ):
                with self.subTest(agent=agent, body=body):
                    completed = cli(
                        agent, TOOL_EVENTS[agent], body, self.state_dir, rules
                    )
                    self.assertEqual(completed.returncode, 0, completed.stderr)
                    value = (
                        json.loads(completed.stdout)
                        if completed.stdout.strip()
                        else None
                    )
                    assert_no_permission(self, value)
                    if agent in ("pi", "opencode"):
                        self.assertIn(value["decision"], ("pass", "advisory"))
                        if value["decision"] == "advisory":
                            self.assertIn("check unavailable", value["notice"])
                            self.assertLessEqual(len(value["notice"]), 320)

    def test_unavailable_state_cannot_restart_a_denial_cycle(self):
        self.state_dir.write_text("not a directory")
        for agent in AGENTS:
            for _ in range(3):
                with self.subTest(agent=agent):
                    decision = invoke(agent, TOOL_EVENTS[agent], publication(agent))
                    assert_record(self, decision, "pass")
                    assert_no_permission(
                        self, wire(agent, TOOL_EVENTS[agent], decision)
                    )

    def test_locked_state_fails_open_without_waiting_for_a_counter(self):
        record = ExtractorRecord("locked-session", "one", "post", None, [])
        state.start_turn("pi", record)
        (path,) = self.state_dir.glob("*.json")
        with path.open("a+") as stream:
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
            for _ in range(3):
                payload = publication("pi", session="locked-session", turn="one")
                decision = invoke("pi", "tool_call", payload)
                assert_record(self, decision, "pass")
                assert_no_permission(self, wire("pi", "tool_call", decision))


if __name__ == "__main__":
    unittest.main()
