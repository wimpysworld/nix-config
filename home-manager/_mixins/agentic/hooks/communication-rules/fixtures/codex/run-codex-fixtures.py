#!/usr/bin/env python3
"""Run focused Codex Communication Rules adapter fixtures."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / "fixtures" / "codex"
ADAPTER = ROOT / "adapters" / "codex.sh"
CONTRACT = ROOT / "adapters" / "contract.sh"
SCANNER = ROOT / "scanner.py"
RULES = ROOT / "communication-rules.md"

BLOCK_START = "Blocked. Revise this prose to follow the Communication Rules."
CORRECTION_START = "Revise the previous response to follow the Communication Rules."
PRETOOLUSE_YIELD_NOTICE = "Communication Rules unmet after retries, output allowed."
FACING_NOTICE = "Communication Rules breach seen, correcting next reply."
PAYLOAD_MARKERS = [
    "Apply",
    "Bash",
    "Edit",
    "Final",
    "Post",
    "Subagent",
    "Write",
]


def scanner_wrapper(temp_dir: Path) -> Path:
    path = temp_dir / "agent-communication-check"
    path.write_text(
        f"#!/usr/bin/env bash\nexec {sys.executable!r} {str(SCANNER)!r} --rules {str(RULES)!r} \"$@\"\n",
        encoding="utf-8",
    )
    path.chmod(0o755)
    return path


def run_adapter(
    fixture_name: str,
    scanner: Path,
    extra_env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env.update(
        {
            "TRIPWIRE_ADAPTER_CONTRACT": str(CONTRACT),
            "TRIPWIRE_SCANNER": str(scanner),
        }
    )
    if extra_env:
        env.update(extra_env)

    return subprocess.run(
        ["bash", str(ADAPTER)],
        input=(FIXTURES / fixture_name).read_text(encoding="utf-8"),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
        check=False,
    )


def run_adapter_payload(
    payload: dict,
    scanner: Path,
    extra_env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env.update(
        {
            "TRIPWIRE_ADAPTER_CONTRACT": str(CONTRACT),
            "TRIPWIRE_SCANNER": str(scanner),
        }
    )
    if extra_env:
        env.update(extra_env)

    return subprocess.run(
        ["bash", str(ADAPTER)],
        input=json.dumps(payload),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
        check=False,
    )


def parse_stdout(name: str, completed: subprocess.CompletedProcess[str]) -> dict | None:
    output = completed.stdout.strip()
    if not output:
        return None
    try:
        return json.loads(output)
    except json.JSONDecodeError as error:
        raise AssertionError(f"{name}: invalid JSON output: {error}: {output!r}") from error


def assert_success(name: str, completed: subprocess.CompletedProcess[str]) -> dict | None:
    if completed.returncode != 0:
        raise AssertionError(
            f"{name}: expected exit 0, got {completed.returncode}\n"
            f"stdout: {completed.stdout}\nstderr: {completed.stderr}"
        )
    return parse_stdout(name, completed)


def assert_no_payload_marker(name: str, reason: str) -> None:
    for marker in PAYLOAD_MARKERS:
        if f"{marker}\u2014payload" in reason:
            raise AssertionError(f"{name}: block reason exposed payload marker {marker!r}")


def assert_pretooluse(
    name: str,
    completed: subprocess.CompletedProcess[str],
    decision: str,
) -> dict:
    parsed = assert_success(name, completed)
    if not isinstance(parsed, dict):
        raise AssertionError(f"{name}: expected PreToolUse JSON output")
    if "decision" in parsed:
        raise AssertionError(f"{name}: PreToolUse must not use top-level decision, got {parsed!r}")
    specific = parsed.get("hookSpecificOutput")
    if not isinstance(specific, dict):
        raise AssertionError(f"{name}: missing hookSpecificOutput, got {parsed!r}")
    if specific.get("hookEventName") != "PreToolUse":
        raise AssertionError(f"{name}: wrong hook event name {specific!r}")
    if specific.get("permissionDecision") != decision:
        raise AssertionError(f"{name}: expected {decision}, got {specific!r}")
    return specific


def assert_block(name: str, completed: subprocess.CompletedProcess[str]) -> None:
    specific = assert_pretooluse(name, completed, "deny")
    reason = specific.get("permissionDecisionReason")
    if not isinstance(reason, str) or not reason.startswith(BLOCK_START):
        raise AssertionError(f"{name}: unexpected deny reason {reason!r}")
    assert_no_payload_marker(name, reason)


def assert_pretooluse_yield(name: str, completed: subprocess.CompletedProcess[str]) -> None:
    specific = assert_pretooluse(name, completed, "allow")
    reason = specific.get("permissionDecisionReason")
    if reason != PRETOOLUSE_YIELD_NOTICE:
        raise AssertionError(f"{name}: unexpected allow notice {reason!r}")


def assert_pretooluse_external_yield(
    name: str,
    completed: subprocess.CompletedProcess[str],
    expected_notice: str,
) -> None:
    # Sub-tier B2 yield: an allow decision whose notice names the tool and target
    # so the breach can be retracted fast.
    specific = assert_pretooluse(name, completed, "allow")
    reason = specific.get("permissionDecisionReason")
    if reason != expected_notice:
        raise AssertionError(f"{name}: unexpected B2 allow notice {reason!r}")


def assert_facing_notice(name: str, completed: subprocess.CompletedProcess[str]) -> None:
    parsed = assert_success(name, completed)
    if not isinstance(parsed, dict):
        raise AssertionError(f"{name}: expected facing notice JSON output")
    if "decision" in parsed or "reason" in parsed or "hookSpecificOutput" in parsed:
        raise AssertionError(f"{name}: facing notice must not block, got {parsed!r}")
    message = parsed.get("systemMessage")
    if message != FACING_NOTICE:
        raise AssertionError(f"{name}: unexpected facing systemMessage {message!r}")


def assert_reissue(name: str, completed: subprocess.CompletedProcess[str]) -> None:
    parsed = assert_success(name, completed)
    if not isinstance(parsed, dict):
        raise AssertionError(f"{name}: expected re-issue JSON output")
    specific = parsed.get("hookSpecificOutput")
    if not isinstance(specific, dict):
        raise AssertionError(f"{name}: missing hookSpecificOutput, got {parsed!r}")
    if specific.get("hookEventName") != "UserPromptSubmit":
        raise AssertionError(f"{name}: wrong hook event name {specific!r}")
    context = specific.get("additionalContext")
    if not isinstance(context, str) or not context.startswith(CORRECTION_START):
        raise AssertionError(f"{name}: unexpected re-issue additionalContext {context!r}")


def assert_pass(name: str, completed: subprocess.CompletedProcess[str]) -> None:
    parsed = assert_success(name, completed)
    if parsed is not None:
        raise AssertionError(f"{name}: expected no output, got {parsed!r}")


def assert_context(name: str, completed: subprocess.CompletedProcess[str], event_name: str) -> None:
    parsed = assert_success(name, completed)
    if not isinstance(parsed, dict):
        raise AssertionError(f"{name}: expected context JSON output")
    specific = parsed.get("hookSpecificOutput")
    if not isinstance(specific, dict):
        raise AssertionError(f"{name}: missing hookSpecificOutput")
    if specific.get("hookEventName") != event_name:
        raise AssertionError(f"{name}: wrong hook event name {specific!r}")
    context = specific.get("additionalContext")
    if not isinstance(context, str) or "Communication Rules:" not in context:
        raise AssertionError(f"{name}: missing reminder context")


def assert_ascii(paths: list[Path]) -> None:
    bad = []
    for path in paths:
        data = path.read_bytes()
        if any(byte > 0x7F for byte in data):
            bad.append(str(path))
    if bad:
        raise AssertionError("non-ASCII fixture files:\n" + "\n".join(bad))


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="tripwire-codex-") as temp:
        temp_dir = Path(temp)
        scanner = scanner_wrapper(temp_dir)
        correction_prompt = temp_dir / "correction-prompt.md"
        correction_prompt.write_text(
            CORRECTION_START
            + " Return only the corrected response.\n\nCommunication Rules:\nUse short sentences.\n",
            encoding="utf-8",
        )
        os.environ["TRIPWIRE_CORRECTION_PROMPT"] = str(correction_prompt)

        context_cases = {
            "session-start.json": "SessionStart",
            "subagent-start.json": "SubagentStart",
        }
        pass_cases = [
            "user-prompt-submit.json",
            "pre-tool-use-apply-patch-clean.json",
            "pre-tool-use-bash-clean.json",
            "pre-tool-use-post-clean.json",
            # Fix 3 regression: a tool named "multiedit" contains the loose part
            # "edit" but is not a post tool. Its breaching body is not extracted
            # as a post, so the call passes rather than being blocked.
            "pre-tool-use-multiedit-surface-local.json",
            "stop-clean.json",
            "subagent-stop-clean.json",
        ]
        block_cases = [
            "pre-tool-use-apply-patch-blocked.json",
            "pre-tool-use-edit-blocked.json",
            "pre-tool-use-write-blocked.json",
            "pre-tool-use-bash-blocked.json",
            "pre-tool-use-post-blocked.json",
            "pre-tool-use-post-extraction-failure.json",
        ]
        # Tier A facing prose: Stop and SubagentStop never block; a breach emits a
        # short notice. Each uses an isolated retry dir so the pending re-issue
        # flag from one case does not leak into another.
        facing_cases = [
            "stop-blocked.json",
            "stop-extraction-failure.json",
            "subagent-stop-blocked.json",
        ]

        for fixture, event_name in context_cases.items():
            assert_context(fixture, run_adapter(fixture, scanner), event_name)

        broken_scanner = Path("/bin/false")
        assert_pass(
            "session-start reminder failure opens",
            run_adapter("session-start.json", broken_scanner),
        )

        for fixture in pass_cases:
            assert_pass(fixture, run_adapter(fixture, scanner))

        assert_pass(
            "stop-policy-disclosure",
            run_adapter_payload(
                {
                    "hook_event_name": "Stop",
                    "session_id": "session-disclosure",
                    "turn_id": "turn-disclosure",
                    "last_assistant_message": RULES.read_text(encoding="utf-8").strip(),
                },
                scanner,
            ),
        )

        for index, fixture in enumerate(block_cases):
            # Isolate each block fixture's strike counter so each starts at deny.
            block_env = {"TRIPWIRE_RETRY_DIR": str(temp_dir / f"block-{index}")}
            assert_block(fixture, run_adapter(fixture, scanner, block_env))

        for index, fixture in enumerate(facing_cases):
            facing_env = {"TRIPWIRE_RETRY_DIR": str(temp_dir / f"facing-{index}")}
            assert_facing_notice(fixture, run_adapter(fixture, scanner, facing_env))

        # Tier B world output: strikes 1 and 2 deny, strike 3 yields and allows.
        strike_dir = temp_dir / "strike-state"
        strike_env = {"TRIPWIRE_RETRY_DIR": str(strike_dir)}
        assert_block(
            "pretooluse strike 1",
            run_adapter("pre-tool-use-write-blocked.json", scanner, strike_env),
        )
        assert_block(
            "pretooluse strike 2",
            run_adapter("pre-tool-use-write-blocked.json", scanner, strike_env),
        )
        assert_pretooluse_yield(
            "pretooluse strike 3",
            run_adapter("pre-tool-use-write-blocked.json", scanner, strike_env),
        )

        # B1 stable-key regression: a model that REVISES the body between retries
        # must still walk the three-strike cap. Three different breaching bodies
        # write to the SAME file_path and session. The stable session+turn+tool+
        # path key means they count as strikes 1, 2 and 3, so the third yields. A
        # per-body hash key would mint a fresh strike-1 key on each revision and
        # never yield (the bug this regression guards).
        vary_dir = temp_dir / "vary-state"
        vary_env = {"TRIPWIRE_RETRY_DIR": str(vary_dir)}
        assert_block(
            "pretooluse vary strike 1",
            run_adapter("pre-tool-use-write-vary-1-blocked.json", scanner, vary_env),
        )
        assert_block(
            "pretooluse vary strike 2",
            run_adapter("pre-tool-use-write-vary-2-blocked.json", scanner, vary_env),
        )
        assert_pretooluse_yield(
            "pretooluse vary strike 3",
            run_adapter("pre-tool-use-write-vary-3-blocked.json", scanner, vary_env),
        )

        # A clean pass on the same key resets the counter, so the next breach
        # starts again at deny rather than at the yield.
        vary_reset_dir = temp_dir / "vary-reset"
        vary_reset_env = {"TRIPWIRE_RETRY_DIR": str(vary_reset_dir)}
        assert_block(
            "pretooluse vary reset breach",
            run_adapter("pre-tool-use-write-vary-1-blocked.json", scanner, vary_reset_env),
        )
        assert_pass(
            "pretooluse vary reset clean pass",
            run_adapter("pre-tool-use-write-vary-clean.json", scanner, vary_reset_env),
        )
        assert_block(
            "pretooluse vary reset breach after pass",
            run_adapter("pre-tool-use-write-vary-2-blocked.json", scanner, vary_reset_env),
        )

        # Sub-tier B2 external posts: irretractable once they yield, so five
        # strikes. Deny on strikes 1-4, yield on strike 5 with the notice naming
        # the tool and target. The strike key is the stable session+turn+tool
        # identity, so two distinct breaching bodies count as strikes 1 and 2,
        # proving reworded posts share one budget rather than resetting.
        external_dir = temp_dir / "external-state"
        external_env = {"TRIPWIRE_RETRY_DIR": str(external_dir)}
        assert_block(
            "external strike 1",
            run_adapter("pre-tool-use-post-target-blocked.json", scanner, external_env),
        )
        assert_block(
            "external strike 2 reworded",
            run_adapter("pre-tool-use-post-reworded-blocked.json", scanner, external_env),
        )
        assert_block(
            "external strike 3",
            run_adapter("pre-tool-use-post-target-blocked.json", scanner, external_env),
        )
        assert_block(
            "external strike 4",
            run_adapter("pre-tool-use-post-target-blocked.json", scanner, external_env),
        )
        assert_pretooluse_external_yield(
            "external strike 5",
            run_adapter("pre-tool-use-post-target-blocked.json", scanner, external_env),
            "Rules breach posted: mcp__github__add_issue_comment 42",
        )

        # Fix 2: a gh post run through the Bash tool is external (B2), not local.
        # It walks the five-strike cap (deny 1-4, yield 5) with a notice naming
        # the gh subcommand, proving the Bash command string is inspected for the
        # gh post signal rather than classifying by tool name alone.
        gh_bash_dir = temp_dir / "gh-bash-state"
        gh_bash_env = {"TRIPWIRE_RETRY_DIR": str(gh_bash_dir)}
        for strike in range(1, 5):
            assert_block(
                f"gh-via-bash strike {strike}",
                run_adapter("pre-tool-use-bash-gh-post-blocked.json", scanner, gh_bash_env),
            )
        assert_pretooluse_external_yield(
            "gh-via-bash strike 5",
            run_adapter("pre-tool-use-bash-gh-post-blocked.json", scanner, gh_bash_env),
            "Rules breach posted: gh pr comment",
        )

        # Sub-tier B2 reset on pass: a clean post on the same session+turn+tool
        # clears the stable counter, so the next breach starts again at deny.
        external_reset_dir = temp_dir / "external-reset"
        external_reset_env = {"TRIPWIRE_RETRY_DIR": str(external_reset_dir)}
        assert_block(
            "external reset breach",
            run_adapter("pre-tool-use-post-target-blocked.json", scanner, external_reset_env),
        )
        assert_pass(
            "external reset clean post",
            run_adapter("pre-tool-use-post-clean-same-target.json", scanner, external_reset_env),
        )
        assert_block(
            "external reset breach after pass",
            run_adapter("pre-tool-use-post-target-blocked.json", scanner, external_reset_env),
        )

        # Strike reset on pass: a clean call clears its own key's counter. The
        # strike key is per body content, so after a clean call no strike file
        # remains and the directory holds no counters for it.
        reset_dir = temp_dir / "strike-reset"
        reset_env = {"TRIPWIRE_RETRY_DIR": str(reset_dir)}
        assert_pass(
            "pretooluse clean leaves no strike",
            run_adapter("pre-tool-use-bash-clean.json", scanner, reset_env),
        )
        leftover = list(reset_dir.glob("*.count")) if reset_dir.is_dir() else []
        if leftover:
            raise AssertionError(
                f"pretooluse clean should leave no strike counter, found {leftover!r}"
            )

        # Tier A handoff: a breaching Stop sets the pending re-issue flag; the
        # next UserPromptSubmit emits the model-only re-issue and clears it. Both
        # fixtures share session-1, so they share the flag.
        reissue_dir = temp_dir / "reissue-state"
        reissue_env = {"TRIPWIRE_RETRY_DIR": str(reissue_dir)}
        assert_facing_notice(
            "reissue stop sets flag",
            run_adapter("stop-blocked.json", scanner, reissue_env),
        )
        flag_root = reissue_dir / "reissue"
        flags_after_stop = list(flag_root.glob("*.flag")) if flag_root.is_dir() else []
        if len(flags_after_stop) != 1:
            raise AssertionError(
                f"reissue: expected one pending flag after Stop, found {flags_after_stop!r}"
            )
        assert_reissue(
            "reissue user prompt submit consumes flag",
            run_adapter("user-prompt-submit.json", scanner, reissue_env),
        )
        flags_after_submit = list(flag_root.glob("*.flag")) if flag_root.is_dir() else []
        if flags_after_submit:
            raise AssertionError(
                f"reissue: expected flag cleared after UserPromptSubmit, found {flags_after_submit!r}"
            )
        assert_pass(
            "reissue user prompt submit without flag",
            run_adapter("user-prompt-submit.json", scanner, reissue_env),
        )

        assert_pass(
            "duplicate pre-tool block output",
            run_adapter(
                "pre-tool-use-apply-patch-blocked.json",
                scanner,
                {"TRIPWIRE_EXISTING_BLOCKED": "1"},
            ),
        )
        assert_pass(
            "duplicate stop facing output",
            run_adapter(
                "stop-blocked.json",
                scanner,
                {"TRIPWIRE_EXISTING_BLOCKED": "1"},
            ),
        )

    assert_ascii([ADAPTER, *sorted(FIXTURES.glob("*"))])
    print("codex fixtures passed: 45")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
