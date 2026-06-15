#!/usr/bin/env python3
"""Run focused Communication Rules scanner fixtures."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "fixtures"
SCANNER = ROOT / "scanner.py"
RULES = ROOT / "communication-rules.md"

BLOCK = 1
PASS = 0

BANNED_TERMS = [
    "delve",
    "leverage",
    "tapestry",
    "robust",
    "seamless",
    "pivotal",
    "crucial",
    "testament",
    "cutting-edge",
    "multifaceted",
    "realm",
    "vibrant",
    "nuanced",
    "intricate",
    "showcasing",
    "streamline",
    "garnered",
    "underpinning",
    "underscores",
]

DASH_CASES = {
    "u2014-prose-blocks.md": BLOCK,
    "u2013-prose-blocks.md": BLOCK,
    "u2014-fenced-code-pass.md": PASS,
    "u2013-fenced-code-pass.md": PASS,
    "u2014-quoted-file-content-block.md": BLOCK,
    "u2013-quoted-file-content-block.md": BLOCK,
}

# Every bash .sh fixture, mapped to its expected outcome by filename suffix:
# the blocks and fails-closed suffixes expect a block, the pass and passes
# suffixes expect a pass. The body-file cases read their bodies relative to the
# fixtures directory, so bash cases run with that directory as the cwd.
BASH_CASES = {
    "bash-arbitrary-args-pass.sh": PASS,
    "bash-chained-command-blocks.sh": BLOCK,
    "bash-command-help-pass.sh": PASS,
    "bash-general-stdout-pass.sh": PASS,
    "bash-pipe-tee-blocks.sh": BLOCK,
    "bash-prose-heredoc-redirection-blocks.sh": BLOCK,
    "bash-prose-redirection-blocks.sh": BLOCK,
    "bash-unrecognised-command-pass.sh": PASS,
    "gh-api-safe-post-readable-body-file-blocks.sh": BLOCK,
    "gh-api-safe-post-resolved-body-blocks.sh": BLOCK,
    "gh-api-safe-post-unresolvable-body-fails-closed.sh": BLOCK,
    "gh-post-heredoc-body-file-blocks.sh": BLOCK,
    "gh-post-heredoc-body-file-passes.sh": PASS,
    "gh-post-readable-body-file-blocks.sh": BLOCK,
    "gh-post-readable-body-file-passes.sh": PASS,
    "gh-post-resolved-body-blocks.sh": BLOCK,
    "gh-post-unreadable-body-file-fails-closed.sh": BLOCK,
    "gh-post-unresolvable-body-fails-closed.sh": BLOCK,
    "gh-post-unresolved-command-substitution-fails-closed.sh": BLOCK,
    "gh-post-unresolved-variable-fails-closed.sh": BLOCK,
}


def fixture_text(path: Path) -> str:
    text = path.read_text(encoding="utf-8")
    return text.replace("\\u2014", chr(0x2014)).replace("\\u2013", chr(0x2013))


def expected_fixtures() -> list[str]:
    names = list(DASH_CASES) + list(BASH_CASES)
    for term in BANNED_TERMS:
        names.append(f"banned-word-{term}-boundary.md")
    for term in BANNED_TERMS:
        names.append(f"banned-word-{term}-substring-pass.md")
    return names


def run_scanner(
    args: list[str],
    input_text: str | None = None,
    cwd: Path | None = None,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCANNER), "--rules", str(RULES), *args],
        input=input_text,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        cwd=str(cwd) if cwd is not None else None,
    )


def assert_result(name: str, completed: subprocess.CompletedProcess[str], expected: int) -> None:
    expected_word = "block" if expected == BLOCK else "pass"
    output = completed.stdout.strip()
    if completed.returncode != expected or output != expected_word:
        detail = completed.stderr.strip()
        if detail:
            detail = f"\nstderr: {detail}"
        raise AssertionError(
            f"{name}: expected {expected_word} with exit {expected}, "
            f"got {output!r} with exit {completed.returncode}{detail}"
        )


def scan_file_case(path: Path, expected: int) -> None:
    with tempfile.TemporaryDirectory(prefix="tripwire-fixture-") as temp_dir:
        materialised = Path(temp_dir) / path.name
        materialised.write_text(fixture_text(path), encoding="utf-8")
        completed = run_scanner(["scan-file", str(materialised)])
    assert_result(path.name, completed, expected)


def scan_bash_case(path: Path, expected: int) -> None:
    completed = run_scanner(["scan-bash"], input_text=fixture_text(path), cwd=FIXTURES)
    assert_result(path.name, completed, expected)


def scan_policy_disclosure_cases() -> int:
    rules = RULES.read_text(encoding="utf-8").strip()
    cases = {
        "policy body": (rules, PASS),
        "policy heading": (f"Communication Rules:\n{rules}", PASS),
        "policy quote": ("\n".join(f"> {line}" if line else ">" for line in rules.splitlines()), PASS),
        "policy with prose": (f"Here are the rules:\n{rules}", BLOCK),
    }
    for name, (text, expected) in cases.items():
        assert_result(name, run_scanner(["scan-text"], input_text=text), expected)
    return len(cases)


# --- Claude Code agent fixtures --------------------------------------------
#
# Drive "scanner.py claude-code <event>" over fixtures/claude-code/*.json and
# assert the FULL core decision record (decision, surface, notice, level), not
# the verb alone. Each expectation maps from the old per-adapter expectation in
# fixtures/claude-code/run-fixtures.sh:
#
#   old run-fixtures.sh stdout      core decision record
#   --------------------------      ------------------------------------------
#   empty (pass)                    decision=pass
#   pretooluse-deny (B1)            decision=block, surface=B1, level=warning
#   pretooluse-deny (B2)            decision=block, surface=B2, level=error
#   pretooluse-yield                decision=yield, surface=B1, LOCAL_YIELD_NOTICE
#   pretooluse-external-yield       decision=yield, surface=B2, B2 notice, error
#   pretooluse-external-yield-bash  decision=yield, surface=B2, gh notice, error
#   facing-notice                   decision=block, surface=tierA, FACING_NOTICE
#   reissue                         decision=re-issue, append_correction=true
#   duplicate (existing-blocked)    decision=block, empty notice (no second strike)
#
# The strike counter is file-backed and keyed per session+tool+target, so the
# groups below reset the strike dir between independent sequences exactly as the
# old harness called reset_strikes.
CLAUDE_CODE_FX = FIXTURES / "claude-code"

LOCAL_YIELD_NOTICE = "Communication Rules unmet after retries, output allowed."
FACING_NOTICE = "Communication Rules breach seen, correcting next reply."


def _expect(decision: str, surface: str, notice: str = "", level: str = "warning", append_correction: bool = False) -> dict:
    return {
        "decision": decision,
        "surface": surface,
        "notice": notice,
        "level": level,
        "append_correction": append_correction,
    }


# B1 gating blocks and yields.
_B1_BLOCK = _expect("block", "B1", level="warning")
_B1_YIELD = _expect("yield", "B1", notice=LOCAL_YIELD_NOTICE, level="warning")
_PASS_TIERB = _expect("pass", "B1", level="warning")
# B2 gating blocks and yields.
_B2_BLOCK = _expect("block", "B2", level="error")
# Tier A facing.
_FACING = _expect("block", "tierA", notice=FACING_NOTICE, level="warning")
_PASS_TIERA = _expect("pass", "tierA", level="warning")
_REISSUE = _expect("re-issue", "tierA", append_correction=True)


def _b2_yield(notice: str) -> dict:
    return _expect("yield", "B2", notice=notice, level="error")


def run_claude_code_agent_cases(env: dict, strike_dir: str, reissue_dir: str) -> int:
    """Run the claude-code fixture sequence, asserting the full record.

    Mirrors the group structure of the old run-fixtures.sh. Returns the number
    of asserted cases.
    """
    fixture_dir = str(CLAUDE_CODE_FX)
    count = 0

    def reset_strikes() -> None:
        # Match the old reset_strikes: drop the whole strike root so each group
        # starts a fresh count, since fixtures share one session+tool+target key.
        for child in Path(strike_dir).glob("*"):
            try:
                child.unlink()
            except OSError:
                pass

    def materialise(name: str) -> str:
        text = (CLAUDE_CODE_FX / name).read_text(encoding="utf-8")
        return text.replace("__TRANSCRIPT_DIR__", fixture_dir)

    def run_case(name: str, event: str, expected: dict, existing_blocked: bool = False) -> None:
        nonlocal count
        case_env = dict(env)
        if existing_blocked:
            case_env["TRIPWIRE_EXISTING_BLOCKED"] = "1"
        completed = subprocess.run(
            [sys.executable, str(SCANNER), "--rules", str(RULES), "claude-code", event],
            input=materialise(name),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            env=case_env,
        )
        if completed.returncode != 0:
            raise AssertionError(
                f"claude-code {name} {event}: exit {completed.returncode}, "
                f"stderr={completed.stderr.strip()!r}"
            )
        try:
            record = json.loads(completed.stdout.strip())
        except json.JSONDecodeError as error:
            raise AssertionError(f"claude-code {name} {event}: non-JSON {completed.stdout!r}") from error
        for field, want in expected.items():
            got = record.get(field)
            if got != want:
                raise AssertionError(
                    f"claude-code {name} {event}: field {field!r} expected {want!r}, got {got!r} ({record})"
                )
        count += 1

    # SessionStart and a clean UserPromptSubmit: both pass (no pending flag).
    run_case("session-start.json", "SessionStart", _PASS_TIERA)
    run_case("user-prompt-submit.json", "UserPromptSubmit", _PASS_TIERA)

    # B1 write: pass, then three strikes (deny, deny, yield) on a shared key.
    reset_strikes()
    run_case("pre-tool-use-write-pass.json", "PreToolUse", _PASS_TIERB)
    reset_strikes()
    run_case("pre-tool-use-write-block.json", "PreToolUse", _B1_BLOCK)
    run_case("pre-tool-use-write-block.json", "PreToolUse", _B1_BLOCK)
    run_case("pre-tool-use-write-block.json", "PreToolUse", _B1_YIELD)

    # B1 stable-key regression: three different bodies, one file_path+session.
    reset_strikes()
    run_case("pre-tool-use-write-vary-1-block.json", "PreToolUse", _B1_BLOCK)
    run_case("pre-tool-use-write-vary-2-block.json", "PreToolUse", _B1_BLOCK)
    run_case("pre-tool-use-write-vary-3-block.json", "PreToolUse", _B1_YIELD)

    # A clean pass on the same key resets the counter.
    reset_strikes()
    run_case("pre-tool-use-write-vary-1-block.json", "PreToolUse", _B1_BLOCK)
    run_case("pre-tool-use-write-pass.json", "PreToolUse", _PASS_TIERB)
    run_case("pre-tool-use-write-vary-2-block.json", "PreToolUse", _B1_BLOCK)

    # Extraction failure fails closed on a gating surface: deny, not pass.
    reset_strikes()
    run_case("pre-tool-use-write-extraction-failure.json", "PreToolUse", _B1_BLOCK)

    reset_strikes()
    run_case("pre-tool-use-edit-pass.json", "PreToolUse", _PASS_TIERB)
    run_case("pre-tool-use-edit-block.json", "PreToolUse", _B1_BLOCK)

    reset_strikes()
    run_case("pre-tool-use-bash-pass.json", "PreToolUse", _PASS_TIERB)
    run_case("pre-tool-use-bash-block.json", "PreToolUse", _B1_BLOCK)

    # An MCP post is an external (B2) surface, so even its clean pass tags B2.
    reset_strikes()
    run_case("pre-tool-use-mcp-post-pass.json", "PreToolUse", _expect("pass", "B2", level="warning"))
    run_case("pre-tool-use-mcp-post-block.json", "PreToolUse", _B2_BLOCK)

    # A clean pass on the same target resets the counter, so the next breach is
    # strike 1 (deny), never the yield.
    reset_strikes()
    run_case("pre-tool-use-write-block.json", "PreToolUse", _B1_BLOCK)
    run_case("pre-tool-use-write-block.json", "PreToolUse", _B1_BLOCK)
    run_case("pre-tool-use-write-pass.json", "PreToolUse", _PASS_TIERB)
    run_case("pre-tool-use-write-block.json", "PreToolUse", _B1_BLOCK)

    # B2 external MCP post: five-strike cap. Deny 1-4, yield on 5 with the
    # operator notice naming the tool and target.
    reset_strikes()
    for _ in range(4):
        run_case("pre-tool-use-mcp-post-target-block.json", "PreToolUse", _B2_BLOCK)
    run_case(
        "pre-tool-use-mcp-post-target-block.json",
        "PreToolUse",
        _b2_yield("Rules breach posted: mcp__github__add_issue_comment 42"),
    )

    # The stable B2 key means reworded bodies share one budget; a clean post
    # resets the counter.
    reset_strikes()
    run_case("pre-tool-use-mcp-post-block.json", "PreToolUse", _B2_BLOCK)
    run_case("pre-tool-use-mcp-post-block-reworded.json", "PreToolUse", _B2_BLOCK)
    run_case("pre-tool-use-mcp-post-pass.json", "PreToolUse", _expect("pass", "B2", level="warning"))
    run_case("pre-tool-use-mcp-post-block.json", "PreToolUse", _B2_BLOCK)

    # B2 gh-via-Bash: a gh post run through Bash walks the five-strike cap with a
    # notice naming the gh subcommand. The body routes through scan_bash.
    reset_strikes()
    for _ in range(4):
        run_case("pre-tool-use-bash-gh-post-target-block.json", "PreToolUse", _B2_BLOCK)
    run_case(
        "pre-tool-use-bash-gh-post-target-block.json",
        "PreToolUse",
        _b2_yield("Rules breach posted: gh pr comment"),
    )

    # Tier A facing prose: clean pass, breach notice, never block-then-reroll.
    run_case("stop-transcript-pass.json", "Stop", _PASS_TIERA)
    run_case("stop-transcript-block.json", "Stop", _FACING)

    # Pending re-issue flow: the breaching Stop above set the flag for
    # session-fixture; the next UserPromptSubmit re-issues and clears it, and a
    # second UserPromptSubmit does not repeat.
    run_case("user-prompt-submit.json", "UserPromptSubmit", _REISSUE)
    run_case("user-prompt-submit.json", "UserPromptSubmit", _PASS_TIERA)

    # Extraction failure on a facing surface fails closed to a re-issue notice,
    # not a block-and-reroll.
    run_case("stop-transcript-extraction-failure.json", "Stop", _FACING)

    # Existing-blocked per-turn dedupe: a duplicate breach takes no second
    # notice (and no second strike). The decision stays block with empty notice.
    reset_strikes()
    run_case("pre-tool-use-write-block.json", "PreToolUse", _expect("block", "B1", level="warning"), existing_blocked=True)
    run_case("stop-transcript-block.json", "Stop", _expect("block", "tierA", level="warning"), existing_blocked=True)

    # SubagentStop mirrors the Stop facing path: clean pass, breach notice.
    run_case("subagent-stop-pass.json", "SubagentStop", _PASS_TIERA)
    run_case("subagent-stop-block.json", "SubagentStop", _FACING)

    return count


def claude_code_agent_cases() -> int:
    """Set up the temp strike/reissue/correction env and run the claude-code cases."""
    with tempfile.TemporaryDirectory(prefix="tripwire-cc-") as temp_dir:
        strike_dir = str(Path(temp_dir) / "pretooluse-strikes")
        reissue_dir = str(Path(temp_dir) / "pending-reissue")
        Path(strike_dir).mkdir(parents=True, exist_ok=True)
        Path(reissue_dir).mkdir(parents=True, exist_ok=True)
        correction = Path(temp_dir) / "correction-prompt.md"
        correction.write_text(
            "Revise the previous response to follow the Communication Rules.\n",
            encoding="utf-8",
        )
        env = dict(os.environ)
        env["TRIPWIRE_CLAUDE_CODE_STRIKE_DIR"] = strike_dir
        env["TRIPWIRE_CLAUDE_CODE_REISSUE_DIR"] = reissue_dir
        env["TRIPWIRE_CORRECTION_PROMPT"] = str(correction)
        env.pop("TRIPWIRE_EXISTING_BLOCKED", None)
        return run_claude_code_agent_cases(env, strike_dir, reissue_dir)


# --- Codex agent fixtures ---------------------------------------------------
#
# Drive "scanner.py codex <event>" over fixtures/codex/*.json and assert the
# FULL core decision record. Each expectation maps from the old per-adapter
# expectation in fixtures/codex/run-codex-fixtures.py:
#
#   old run-codex-fixtures.py assertion   core decision record
#   -----------------------------------   ----------------------------------
#   assert_pass                           decision=pass
#   assert_block                          decision=block (B1 or B2 by surface)
#   assert_pretooluse_yield               decision=yield, surface=B1, notice
#   assert_pretooluse_external_yield      decision=yield, surface=B2, error
#   assert_facing_notice                  decision=block, surface=tierA, notice
#   assert_reissue                        decision=re-issue, append_correction
#   duplicate (existing-blocked)          decision=block, empty notice
#
# Codex keeps its per-turn reset: the strike key includes turn_id, so a new
# turn id starts a fresh B1 count. SessionStart, SubagentStart, and clean
# UserPromptSubmit (no pending flag) all pass through the core gating path.
CODEX_FX = FIXTURES / "codex"


def run_codex_agent_cases(env: dict, strike_dir: str) -> int:
    """Run the codex fixture sequence, asserting the full record."""
    count = 0

    def reset_strikes() -> None:
        for child in Path(strike_dir).glob("*"):
            if child.is_file():
                try:
                    child.unlink()
                except OSError:
                    pass

    def run_case(
        name: str,
        event: str,
        expected: dict,
        existing_blocked: bool = False,
        payload: dict | None = None,
    ) -> None:
        nonlocal count
        case_env = dict(env)
        if existing_blocked:
            case_env["TRIPWIRE_EXISTING_BLOCKED"] = "1"
        if payload is not None:
            input_text = json.dumps(payload)
        else:
            input_text = (CODEX_FX / name).read_text(encoding="utf-8")
        completed = subprocess.run(
            [sys.executable, str(SCANNER), "--rules", str(RULES), "codex", event],
            input=input_text,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            env=case_env,
        )
        if completed.returncode != 0:
            raise AssertionError(
                f"codex {name} {event}: exit {completed.returncode}, "
                f"stderr={completed.stderr.strip()!r}"
            )
        try:
            record = json.loads(completed.stdout.strip())
        except json.JSONDecodeError as error:
            raise AssertionError(f"codex {name} {event}: non-JSON {completed.stdout!r}") from error
        for field, want in expected.items():
            got = record.get(field)
            if got != want:
                raise AssertionError(
                    f"codex {name} {event}: field {field!r} expected {want!r}, got {got!r} ({record})"
                )
        count += 1

    # SessionStart, SubagentStart, and a clean UserPromptSubmit all pass.
    run_case("session-start.json", "SessionStart", _PASS_TIERA)
    run_case("subagent-start.json", "SubagentStart", _PASS_TIERA)
    run_case("user-prompt-submit.json", "UserPromptSubmit", _PASS_TIERA)

    # Pass cases: clean apply_patch, bash, post, multiedit (not a post tool),
    # and clean facing prose.
    reset_strikes()
    run_case("pre-tool-use-apply-patch-clean.json", "PreToolUse", _PASS_TIERB)
    run_case("pre-tool-use-bash-clean.json", "PreToolUse", _PASS_TIERB)
    run_case("pre-tool-use-post-clean.json", "PreToolUse", _expect("pass", "B2", level="warning"))
    # multiedit is not a post tool, so it routes through the non-gating pass
    # (surface tierA), matching the old adapter's assert_pass (no output).
    run_case("pre-tool-use-multiedit-surface-local.json", "PreToolUse", _PASS_TIERA)
    run_case("stop-clean.json", "Stop", _PASS_TIERA)
    run_case("subagent-stop-clean.json", "SubagentStop", _PASS_TIERA)

    # Block cases: each on its own fresh counter, so each is strike 1 (deny).
    # apply_patch, edit, write, bash are B1 local; the mcp post is B2 external;
    # the post extraction failure fails closed to a B2 block.
    for name, expected in (
        ("pre-tool-use-apply-patch-blocked.json", _B1_BLOCK),
        ("pre-tool-use-edit-blocked.json", _B1_BLOCK),
        ("pre-tool-use-write-blocked.json", _B1_BLOCK),
        ("pre-tool-use-bash-blocked.json", _B1_BLOCK),
        ("pre-tool-use-post-blocked.json", _B2_BLOCK),
        ("pre-tool-use-post-extraction-failure.json", _B2_BLOCK),
    ):
        reset_strikes()
        run_case(name, "PreToolUse", expected)

    # B1 three-strike-then-yield on a shared session+turn+tool+path key.
    reset_strikes()
    run_case("pre-tool-use-write-blocked.json", "PreToolUse", _B1_BLOCK)
    run_case("pre-tool-use-write-blocked.json", "PreToolUse", _B1_BLOCK)
    run_case("pre-tool-use-write-blocked.json", "PreToolUse", _B1_YIELD)

    # Codex per-turn reset: the same write breach on a NEW turn id starts a fresh
    # B1 count (strike 1, deny), proving the turn is in the key. The write-blocked
    # fixture is turn-1; vary the turn_id to a second turn.
    reset_strikes()
    base_write = json.loads((CODEX_FX / "pre-tool-use-write-blocked.json").read_text(encoding="utf-8"))
    turn_one = dict(base_write, turn_id="turn-A")
    turn_two = dict(base_write, turn_id="turn-B")
    run_case("write turn-A strike 1", "PreToolUse", _B1_BLOCK, payload=turn_one)
    run_case("write turn-A strike 2", "PreToolUse", _B1_BLOCK, payload=turn_one)
    # A different turn id resets to strike 1 rather than yielding on the third.
    run_case("write turn-B strike 1", "PreToolUse", _B1_BLOCK, payload=turn_two)

    # B1 stable-key regression: three different bodies, one file_path+session+turn.
    reset_strikes()
    run_case("pre-tool-use-write-vary-1-blocked.json", "PreToolUse", _B1_BLOCK)
    run_case("pre-tool-use-write-vary-2-blocked.json", "PreToolUse", _B1_BLOCK)
    run_case("pre-tool-use-write-vary-3-blocked.json", "PreToolUse", _B1_YIELD)

    # A clean pass on the same key resets the counter.
    reset_strikes()
    run_case("pre-tool-use-write-vary-1-blocked.json", "PreToolUse", _B1_BLOCK)
    run_case("pre-tool-use-write-vary-clean.json", "PreToolUse", _PASS_TIERB)
    run_case("pre-tool-use-write-vary-2-blocked.json", "PreToolUse", _B1_BLOCK)

    # B2 external MCP post: five-strike cap. Deny 1-4, yield on 5 with the
    # operator notice naming the tool and target. Reworded body shares one budget.
    reset_strikes()
    run_case("pre-tool-use-post-target-blocked.json", "PreToolUse", _B2_BLOCK)
    run_case("pre-tool-use-post-reworded-blocked.json", "PreToolUse", _B2_BLOCK)
    run_case("pre-tool-use-post-target-blocked.json", "PreToolUse", _B2_BLOCK)
    run_case("pre-tool-use-post-target-blocked.json", "PreToolUse", _B2_BLOCK)
    run_case(
        "pre-tool-use-post-target-blocked.json",
        "PreToolUse",
        _b2_yield("Rules breach posted: mcp__github__add_issue_comment 42"),
    )

    # B2 reset on a clean post on the same session+turn+tool.
    reset_strikes()
    run_case("pre-tool-use-post-target-blocked.json", "PreToolUse", _B2_BLOCK)
    run_case("pre-tool-use-post-clean-same-target.json", "PreToolUse", _expect("pass", "B2", level="warning"))
    run_case("pre-tool-use-post-target-blocked.json", "PreToolUse", _B2_BLOCK)

    # B2 gh-via-Bash: a gh post run through Bash walks the five-strike cap with a
    # notice naming the gh subcommand. The body routes through scan_bash.
    reset_strikes()
    for _ in range(4):
        run_case("pre-tool-use-bash-gh-post-blocked.json", "PreToolUse", _B2_BLOCK)
    run_case(
        "pre-tool-use-bash-gh-post-blocked.json",
        "PreToolUse",
        _b2_yield("Rules breach posted: gh pr comment"),
    )

    # Tier A facing prose: Stop and SubagentStop never block; a breach (or an
    # extraction failure) sets the pending flag and emits the facing notice.
    reset_strikes()
    run_case("stop-blocked.json", "Stop", _FACING)
    # The breaching Stop above set the flag for session-1; the next
    # UserPromptSubmit re-issues and clears it, and a second does not repeat.
    run_case("user-prompt-submit.json", "UserPromptSubmit", _REISSUE)
    run_case("user-prompt-submit.json", "UserPromptSubmit", _PASS_TIERA)

    run_case("stop-extraction-failure.json", "Stop", _FACING)
    # Clear the flag set by the extraction-failure Stop so it does not leak.
    run_case("user-prompt-submit.json", "UserPromptSubmit", _REISSUE)

    run_case("subagent-stop-blocked.json", "SubagentStop", _FACING)
    run_case("user-prompt-submit.json", "UserPromptSubmit", _REISSUE)

    # Existing-blocked per-turn dedupe: a duplicate breach takes no second notice
    # (and no second strike). The decision stays block with empty notice.
    reset_strikes()
    run_case(
        "pre-tool-use-apply-patch-blocked.json",
        "PreToolUse",
        _expect("block", "B1", level="warning"),
        existing_blocked=True,
    )
    run_case(
        "stop-blocked.json",
        "Stop",
        _expect("block", "tierA", level="warning"),
        existing_blocked=True,
    )

    return count


def codex_agent_cases() -> int:
    """Set up the temp strike/reissue/correction env and run the codex cases."""
    with tempfile.TemporaryDirectory(prefix="tripwire-codex-") as temp_dir:
        strike_dir = str(Path(temp_dir) / "codex-retries")
        Path(strike_dir).mkdir(parents=True, exist_ok=True)
        correction = Path(temp_dir) / "correction-prompt.md"
        correction.write_text(
            "Revise the previous response to follow the Communication Rules.\n",
            encoding="utf-8",
        )
        env = dict(os.environ)
        # Codex reads its strike dir from TRIPWIRE_RETRY_DIR and nests the
        # reissue flags under it, matching the old adapter layout.
        env["TRIPWIRE_RETRY_DIR"] = strike_dir
        env["TRIPWIRE_CORRECTION_PROMPT"] = str(correction)
        env.pop("TRIPWIRE_EXISTING_BLOCKED", None)
        env.pop("TRIPWIRE_REISSUE_DIR", None)
        return run_codex_agent_cases(env, strike_dir)


# --- Pi agent fixtures ------------------------------------------------------
#
# Drive "scanner.py pi <event>" over fixtures/pi/*.json and assert the FULL core
# decision record. Pi sends its own event handlers (tool_call, message_end,
# tool_result), not the Claude/Codex PreToolUse/Stop names, so each case names
# the Pi handler. Each expectation maps from the old per-adapter expectations in
# fixtures/pi/run-fixtures.sh and run-extension-fixtures.ts:
#
#   old run-fixtures.sh / extension      core decision record
#   ------------------------------       ------------------------------------
#   expect_pass                          decision=pass
#   expect_block (B1 local)              decision=block, surface=B1, warning
#   expect_block (B2 external)           decision=block, surface=B2, error
#   expect_reissue (message_end facing)  decision=block, surface=tierA, FACING
#   expect_duplicate_block               decision=block, empty notice
#   tool_call strike 3 yield (B1)        decision=yield, surface=B1, notice
#   tool_call strike 5 yield (B2)        decision=yield, surface=B2, error notice
#
# Pi has no turn id and a consecutive-block strike counter keyed on
# session+tool+target, so groups reset the strike dir between independent
# sequences, mirroring how the old in-process Map reset per session.
PI_FX = FIXTURES / "pi"

# Pi tool names differ from Claude/Codex: the bash tool is "bash" and a gh post
# names the Pi tool, so the B2 yield notice for a Pi mcp post names the tool and
# target from the fixture (mcp__github__add_issue_comment 42), built at runtime.


def run_pi_agent_cases(env: dict, strike_dir: str) -> int:
    """Run the pi fixture sequence, asserting the full record."""
    count = 0

    def reset_strikes() -> None:
        for child in Path(strike_dir).glob("*"):
            if child.is_file():
                try:
                    child.unlink()
                except OSError:
                    pass

    def run_case(
        name: str,
        event: str,
        expected: dict,
        existing_blocked: bool = False,
        payload: dict | None = None,
    ) -> None:
        nonlocal count
        case_env = dict(env)
        if existing_blocked:
            case_env["TRIPWIRE_EXISTING_BLOCKED"] = "1"
        if payload is not None:
            input_text = json.dumps(payload)
        else:
            input_text = (PI_FX / name).read_text(encoding="utf-8")
        completed = subprocess.run(
            [sys.executable, str(SCANNER), "--rules", str(RULES), "pi", event],
            input=input_text,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            env=case_env,
        )
        if completed.returncode != 0:
            raise AssertionError(
                f"pi {name} {event}: exit {completed.returncode}, "
                f"stderr={completed.stderr.strip()!r}"
            )
        try:
            record = json.loads(completed.stdout.strip())
        except json.JSONDecodeError as error:
            raise AssertionError(f"pi {name} {event}: non-JSON {completed.stdout!r}") from error
        for field, want in expected.items():
            got = record.get(field)
            if got != want:
                raise AssertionError(
                    f"pi {name} {event}: field {field!r} expected {want!r}, got {got!r} ({record})"
                )
        count += 1

    # context emits the reminder (a non-gating pass in the core; the shim turns
    # it into the rules injection). input is a plain pass.
    run_case("context.json", "context", _PASS_TIERA)
    run_case("input.json", "input", _PASS_TIERA)

    # Pass cases: clean tool calls, clean facing prose, clean subagent result.
    reset_strikes()
    run_case("tool-call-write-clean.json", "tool_call", _PASS_TIERB)
    run_case("tool-call-bash-stdout-pass.json", "tool_call", _PASS_TIERB)
    run_case("message-end-final-clean.json", "message_end", _PASS_TIERA)
    # An intermediate tool-use turn is not final prose; it passes (tierA).
    run_case("message-end-tool-use-pass.json", "message_end", _PASS_TIERA)
    run_case("tool-result-subagent-clean.json", "tool_result", _PASS_TIERB)
    # A non-subagent tool_result is not scanned by this gate, so it passes.
    run_case("tool-result-other-tool-pass.json", "tool_result", _PASS_TIERA)

    # B1 local block cases, each on a fresh counter (strike 1, deny). write and
    # apply_patch are local; subagent tool_result is a local gate.
    for name in (
        "tool-call-write-blocked.json",
        "tool-call-patch-blocked.json",
    ):
        reset_strikes()
        run_case(name, "tool_call", _B1_BLOCK)
    reset_strikes()
    run_case("tool-result-subagent-blocked.json", "tool_result", _B1_BLOCK)

    # B1 fail-closed: missing write content and missing subagent content fail
    # closed on a gating surface (deny, never pass).
    reset_strikes()
    run_case("tool-call-write-missing-content-fails-closed.json", "tool_call", _B1_BLOCK)
    reset_strikes()
    run_case(
        "tool-result-subagent-missing-content-fails-closed.json", "tool_result", _B1_BLOCK
    )

    # B2 external block cases: an mcp post and a gh-via-bash post. The gh
    # unresolvable body fails closed to a B2 block.
    reset_strikes()
    run_case("tool-call-mcp-post-blocked.json", "tool_call", _B2_BLOCK)
    reset_strikes()
    run_case("tool-call-bash-post-blocked.json", "tool_call", _B2_BLOCK)
    reset_strikes()
    run_case("tool-call-gh-unresolvable-body-fails-closed.json", "tool_call", _B2_BLOCK)

    # B1 three-strike-then-yield on a shared session+tool+path key (write).
    reset_strikes()
    run_case("tool-call-write-blocked.json", "tool_call", _B1_BLOCK)
    run_case("tool-call-write-blocked.json", "tool_call", _B1_BLOCK)
    run_case("tool-call-write-blocked.json", "tool_call", _B1_YIELD)

    # A clean pass on the same key resets the counter, so the next breach is
    # strike 1 (deny), never the yield.
    reset_strikes()
    run_case("tool-call-write-blocked.json", "tool_call", _B1_BLOCK)
    run_case("tool-call-write-clean.json", "tool_call", _PASS_TIERB)
    run_case("tool-call-write-blocked.json", "tool_call", _B1_BLOCK)

    # B2 external mcp post: five-strike cap. Deny 1-4, yield on 5 with the
    # operator notice naming the tool and target.
    reset_strikes()
    for _ in range(4):
        run_case("tool-call-mcp-post-blocked.json", "tool_call", _B2_BLOCK)
    run_case(
        "tool-call-mcp-post-blocked.json",
        "tool_call",
        _b2_yield("Rules breach posted: mcp__linear__create_comment ISS-1"),
    )

    # Tier A facing prose: a message_end breach (or extraction failure) never
    # blocks the reply; it sets the pending flag and emits the facing notice.
    run_case("message-end-final-blocked.json", "message_end", _FACING)
    run_case("message-end-extraction-failure.json", "message_end", _FACING)

    # Existing-blocked per-turn dedupe: a duplicate breach takes no second notice
    # (and no second strike). The decision stays block with an empty notice.
    reset_strikes()
    run_case(
        "tool-call-write-blocked.json",
        "tool_call",
        _expect("block", "B1", level="warning"),
        existing_blocked=True,
    )
    run_case(
        "message-end-final-blocked.json",
        "message_end",
        _expect("block", "tierA", level="warning"),
        existing_blocked=True,
    )

    return count


def pi_agent_cases() -> int:
    """Set up the temp strike/reissue/correction env and run the pi cases."""
    with tempfile.TemporaryDirectory(prefix="tripwire-pi-") as temp_dir:
        strike_dir = str(Path(temp_dir) / "pi-pretooluse-strikes")
        reissue_dir = str(Path(temp_dir) / "pi-pending-reissue")
        Path(strike_dir).mkdir(parents=True, exist_ok=True)
        Path(reissue_dir).mkdir(parents=True, exist_ok=True)
        correction = Path(temp_dir) / "correction-prompt.md"
        correction.write_text(
            "Revise the previous response to follow the Communication Rules.\n",
            encoding="utf-8",
        )
        env = dict(os.environ)
        env["TRIPWIRE_PI_STRIKE_DIR"] = strike_dir
        env["TRIPWIRE_PI_REISSUE_DIR"] = reissue_dir
        env["TRIPWIRE_CORRECTION_PROMPT"] = str(correction)
        env.pop("TRIPWIRE_EXISTING_BLOCKED", None)
        return run_pi_agent_cases(env, strike_dir)


# --- OpenCode agent fixtures ------------------------------------------------
#
# Drive "scanner.py opencode <event>" over fixtures/opencode/*.json and assert
# the FULL core decision record. OpenCode sends a tool.execute.before gate event
# and message.final / subagent.final display (Tier A facing) events, resolved
# from the payload's "event" field. Each expectation maps from the old
# per-adapter expectation in fixtures/opencode/run-fixtures.py:
#
#   old run-fixtures.py expectation        core decision record
#   ------------------------------------   ----------------------------------
#   check_tool_pass (pass\n, exit 0)       decision=pass
#   check_tool_block local (block\n)       decision=block, surface=B1, warning
#   check_tool_block external post         decision=block, surface=B2, error
#   tool strike 3 yield (plugin B1)        decision=yield, surface=B1, notice
#   external strike 5 yield (plugin B2)    decision=yield, surface=B2, error
#   duplicate (--existing-blocked)         decision=block, empty notice
#   check_post_correction (correction)     decision=block, surface=tierA, FACING
#   post-display-clean / disclosure pass   decision=pass, surface=tierA
#
# OpenCode has no turn id; its strike counter keys on session+tool+target, so
# groups reset the strike dir between independent sequences, mirroring the old
# in-process Map reset per session.
OPENCODE_FX = FIXTURES / "opencode"


def run_opencode_agent_cases(env: dict, strike_dir: str) -> int:
    """Run the opencode fixture sequence, asserting the full record."""
    count = 0

    def reset_strikes() -> None:
        for child in Path(strike_dir).glob("*"):
            if child.is_file():
                try:
                    child.unlink()
                except OSError:
                    pass

    def run_case(
        name: str,
        event: str,
        expected: dict,
        existing_blocked: bool = False,
        payload: dict | None = None,
    ) -> None:
        nonlocal count
        case_env = dict(env)
        if existing_blocked:
            case_env["TRIPWIRE_EXISTING_BLOCKED"] = "1"
        if payload is not None:
            input_text = json.dumps(payload)
        else:
            input_text = (OPENCODE_FX / name).read_text(encoding="utf-8")
        completed = subprocess.run(
            [sys.executable, str(SCANNER), "--rules", str(RULES), "opencode", event],
            input=input_text,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            env=case_env,
        )
        if completed.returncode != 0:
            raise AssertionError(
                f"opencode {name} {event}: exit {completed.returncode}, "
                f"stderr={completed.stderr.strip()!r}"
            )
        try:
            record = json.loads(completed.stdout.strip())
        except json.JSONDecodeError as error:
            raise AssertionError(f"opencode {name} {event}: non-JSON {completed.stdout!r}") from error
        for field, want in expected.items():
            got = record.get(field)
            if got != want:
                raise AssertionError(
                    f"opencode {name} {event}: field {field!r} expected {want!r}, got {got!r} ({record})"
                )
        count += 1

    # Pass cases: clean write, multiedit, apply_patch context, and a clean gh
    # post. The gh post is an external (B2) surface, so even its clean pass tags
    # B2; the local file tools tag B1.
    reset_strikes()
    run_case("tool-write-clean.json", "tool.execute.before", _PASS_TIERB)
    run_case("tool-multiedit-clean.json", "tool.execute.before", _PASS_TIERB)
    run_case("tool-apply-patch-context-clean.json", "tool.execute.before", _PASS_TIERB)
    run_case("tool-post-clean.json", "tool.execute.before", _expect("pass", "B2", level="warning"))

    # B1 local block cases, each on a fresh counter (strike 1, deny). write,
    # edit, multiedit, apply_patch, and bash are local; the extraction failure
    # (a write with no content) fails closed to a B1 block.
    for name in (
        "tool-write-blocked.json",
        "tool-edit-blocked.json",
        "tool-multiedit-blocked.json",
        "tool-patch-blocked.json",
        "tool-apply-patch-added-blocked.json",
        "tool-bash-blocked.json",
        "tool-extraction-failure.json",
    ):
        reset_strikes()
        run_case(name, "tool.execute.before", _B1_BLOCK)

    # B2 external post: a gh-api-safe post is external, so its breach is a B2
    # block.
    reset_strikes()
    run_case("tool-post-blocked.json", "tool.execute.before", _B2_BLOCK)

    # B1 three-strike-then-yield on a shared session+tool+path key (write).
    reset_strikes()
    run_case("tool-write-blocked.json", "tool.execute.before", _B1_BLOCK)
    run_case("tool-write-blocked.json", "tool.execute.before", _B1_BLOCK)
    run_case("tool-write-blocked.json", "tool.execute.before", _B1_YIELD)

    # A clean pass on the same key resets the counter, so the next breach is
    # strike 1 (deny), never the yield.
    reset_strikes()
    run_case("tool-write-blocked.json", "tool.execute.before", _B1_BLOCK)
    run_case("tool-write-clean.json", "tool.execute.before", _PASS_TIERB)
    run_case("tool-write-blocked.json", "tool.execute.before", _B1_BLOCK)

    # B2 external post: five-strike cap. Deny 1-4, yield on 5 with the operator
    # notice naming the tool and target. The gh-api-safe post fixture has a
    # command (no structured identifier), so the target falls back to the tool.
    reset_strikes()
    for _ in range(4):
        run_case("tool-post-blocked.json", "tool.execute.before", _B2_BLOCK)
    run_case(
        "tool-post-blocked.json",
        "tool.execute.before",
        _b2_yield("Rules breach posted: gh-api-safe"),
    )

    # Tier A facing prose: a clean final passes; a blocked final or subagent sets
    # the pending flag and emits the facing notice, never blocking the reply.
    run_case("post-display-clean.json", "message.final", _PASS_TIERA)
    run_case("post-display-final-blocked.json", "message.final", _FACING)
    run_case("post-display-subagent-blocked.json", "subagent.final", _FACING)

    # Policy disclosure (the rules themselves) on a display surface is exempt and
    # passes. Built at runtime from the rules file so this file holds no banned
    # term and no rules copy.
    rules_text = RULES.read_text(encoding="utf-8").strip()
    run_case(
        "policy-disclosure",
        "message.final",
        _PASS_TIERA,
        payload={
            "event": "message.final",
            "surface": "final",
            "session_id": "oc-disclosure",
            "message": {"content": rules_text},
        },
    )

    # Tier A extraction failure (final and subagent): a recognised display
    # surface whose body cannot be resolved must RE-ISSUE, not block. It fails
    # OPEN to the facing path (a Tier A block that sets the pending flag and
    # emits the facing notice), never a hard tool block or yield. Each uses a
    # fresh session so the pending flag does not leak between the two.
    run_case(
        "final-extraction-failure",
        "message.final",
        _FACING,
        payload={"event": "message.final", "surface": "final", "session_id": "oc-empty-final"},
    )
    run_case(
        "subagent-extraction-failure",
        "subagent.final",
        _FACING,
        payload={"event": "subagent.final", "surface": "subagent", "session_id": "oc-empty-subagent"},
    )

    # Existing-blocked per-turn dedupe: a duplicate breach takes no second notice
    # (and no second strike). The decision stays block with an empty notice.
    reset_strikes()
    run_case(
        "tool-duplicate-existing-blocked.json",
        "tool.execute.before",
        _expect("block", "B1", level="warning"),
        existing_blocked=True,
    )

    return count


def opencode_agent_cases() -> int:
    """Set up the temp strike/reissue/correction env and run the opencode cases."""
    with tempfile.TemporaryDirectory(prefix="tripwire-opencode-") as temp_dir:
        strike_dir = str(Path(temp_dir) / "opencode-pretooluse-strikes")
        reissue_dir = str(Path(temp_dir) / "opencode-pending-reissue")
        Path(strike_dir).mkdir(parents=True, exist_ok=True)
        Path(reissue_dir).mkdir(parents=True, exist_ok=True)
        correction = Path(temp_dir) / "correction-prompt.md"
        correction.write_text(
            "Revise the previous response to follow the Communication Rules.\n",
            encoding="utf-8",
        )
        env = dict(os.environ)
        env["TRIPWIRE_OPENCODE_STRIKE_DIR"] = strike_dir
        env["TRIPWIRE_OPENCODE_REISSUE_DIR"] = reissue_dir
        env["TRIPWIRE_CORRECTION_PROMPT"] = str(correction)
        env.pop("TRIPWIRE_EXISTING_BLOCKED", None)
        return run_opencode_agent_cases(env, strike_dir)


def main() -> int:
    missing = [name for name in expected_fixtures() if not (FIXTURES / name).is_file()]
    if missing:
        for name in missing:
            print(f"missing fixture: {name}", file=sys.stderr)
        return 2

    total = 0
    for name, expected in DASH_CASES.items():
        scan_file_case(FIXTURES / name, expected)
        total += 1

    for term in BANNED_TERMS:
        scan_file_case(FIXTURES / f"banned-word-{term}-boundary.md", BLOCK)
        total += 1

    for term in BANNED_TERMS:
        scan_file_case(FIXTURES / f"banned-word-{term}-substring-pass.md", PASS)
        total += 1

    for name, expected in BASH_CASES.items():
        scan_bash_case(FIXTURES / name, expected)
        total += 1

    total += scan_policy_disclosure_cases()

    scanner_total = total
    claude_total = claude_code_agent_cases()
    total += claude_total
    codex_total = codex_agent_cases()
    total += codex_total
    pi_total = pi_agent_cases()
    total += pi_total
    opencode_total = opencode_agent_cases()
    total += opencode_total

    print(f"scanner fixtures passed: {scanner_total}")
    print(f"claude-code agent fixtures passed: {claude_total}")
    print(f"codex agent fixtures passed: {codex_total}")
    print(f"pi agent fixtures passed: {pi_total}")
    print(f"opencode agent fixtures passed: {opencode_total}")
    print(f"total fixtures passed: {total}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
