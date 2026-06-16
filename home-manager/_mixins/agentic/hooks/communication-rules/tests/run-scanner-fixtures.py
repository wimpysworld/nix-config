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
#   pretooluse-allow (B1 revise)    decision=allow-revise, surface=B1, revision notice
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

FACING_NOTICE = "Communication Rules breach seen, correcting next reply."


def _expect(decision: str, surface: str, notice: str = "", level: str = "warning", append_correction: bool = False) -> dict:
    return {
        "decision": decision,
        "surface": surface,
        "notice": notice,
        "level": level,
        "append_correction": append_correction,
    }


def _b2_block(nudge: bool = False) -> dict:
    """A B2 block expectation for a middle block (nudge) or a full-rules block.

    ``nudge=True`` is a middle block of the external cap (strikes 2 .. limit - 2):
    the core carries the short ``EXTERNAL_REPEAT_NOTICE`` in ``decision.notice``,
    which the plugin shims emit as the block reason and the dispatcher promotes to
    the command-agent deny reason. ``nudge=False`` is the first or penultimate
    block, which re-issues the full rules (an empty ``notice``; the command deny
    reason is the full block message, matched by prefix).

    The same expectation feeds both layers. The plugin runner reads the raw
    ``Decision`` and asserts ``notice`` directly. The command-agent wire runner
    reads ``block_message`` to decide whether the deny reason is the exact nudge
    (``EXTERNAL_REPEAT_NOTICE``) or the full-rules prefix.
    """
    if nudge:
        expected = _expect("block", "B2", notice=_B2_REPEAT_NOTICE, level="error")
        expected["block_message"] = _B2_REPEAT_NOTICE
    else:
        expected = _expect("block", "B2", notice="", level="error")
        expected["block_message"] = None
    return expected


# B1 gating blocks and the hybrid allow-revise.
_B1_BLOCK = _expect("block", "B1", level="warning")
_PASS_TIERB = _expect("pass", "B1", level="warning")


# Stable substrings of the resolved B1 revision notice. The runner loads only
# --rules (no --policy-json, no TRIPWIRE_B1_REVISION_PROMPT), so the scanner
# resolves the baked FALLBACK_B1_REVISION_PROMPT in core/config.py. We match a
# fixed clause plus the concrete target, not the whole prompt, to stay safe
# against wording tweaks. No literal "{target}" must ever appear.
_B1_REVISION_CLAUSE = "Revise it in place to comply:"
_B1_REVISION_TRAILER = "Do not rewrite unrelated content."
# The generic form used when the target is empty (a Bash B1 breach). It names no
# file and carries no placeholder.
_B1_REVISION_GENERIC = "Revise the prose you just wrote to comply with the Communication Rules."
_TARGET_PLACEHOLDER = "{target}"


def _b1_allow_revise(target: str = "") -> dict:
    """Expectation for a B1 strike-2+ allow-revise on a given target.

    ``target`` is the RAW stable target the gate places in ``decision.notice``
    (the file path for a file tool, empty for a Bash B1 breach). The plugin
    agents (Pi, OpenCode) assert this record as is: the scanner emits the raw
    decision and the TS shim resolves the prompt. The command agents (Claude
    Code, Codex) reshape it in ``expected_wire`` into an allow whose reason is
    the RESOLVED revision prompt naming that target.
    """
    return _expect("allow-revise", "B1", notice=target, level="warning")


def _assert_no_target_placeholder(name: str, notice: object) -> None:
    """Guard: no plugin notice may carry a literal ``{target}`` placeholder.

    The scanner emits the raw decision for plugin agents, so the notice is the
    bare target the gate set (a path, or empty for a Bash B1 breach), never a
    half-substituted template. A literal ``{target}`` would mean the gate leaked
    the placeholder into the record.
    """
    if isinstance(notice, str) and _TARGET_PLACEHOLDER in notice:
        raise AssertionError(f"{name}: notice carries a literal {_TARGET_PLACEHOLDER}: {notice!r}")
# B2 gating blocks and yields.
_B2_BLOCK = _expect("block", "B2", level="error")

# The short B2 nudge the core emits on the middle blocks of the external cap
# (strikes 2 .. limit - 2). The first and the penultimate block re-issue the
# full rules; the blocks in between carry this instead. Byte-identical to
# ``core.state.EXTERNAL_REPEAT_NOTICE``.
_B2_REPEAT_NOTICE = "Communication Rules still unmet. Revise the body to comply before posting."
# Tier A facing.
_FACING = _expect("block", "tierA", notice=FACING_NOTICE, level="warning")
_PASS_TIERA = _expect("pass", "tierA", level="warning")
_REISSUE = _expect("re-issue", "tierA", append_correction=True)
# SessionStart / SubagentStart inject the rules reminder.
_REMIND = _expect("remind", "tierA")


def _b2_yield(notice: str) -> dict:
    return _expect("yield", "B2", notice=notice, level="error")


def _assert_record_fields(label: str, record: dict, expected: dict) -> None:
    """Assert a plugin agent's raw decision record matches the expectation.

    The plugin shims read the raw ``Decision`` JSON, which has no
    ``block_message`` field, so that key is a command-agent wire hint only and is
    skipped here. The B2 nudge versus full-rules distinction is asserted on
    ``notice``: a middle block carries ``EXTERNAL_REPEAT_NOTICE``, a first or
    penultimate block carries an empty notice (the shim then emits the full cached
    rules as the block reason). Every other field compares for equality.
    """
    for field, want in expected.items():
        if field == "block_message":
            continue
        got = record.get(field)
        if got != want:
            raise AssertionError(
                f"{label}: field {field!r} expected {want!r}, got {got!r} ({record})"
            )


# --- Command-hook wire-shape assertions ------------------------------------
#
# Claude Code and Codex command hooks pipe scanner stdout straight into the
# agent, which validates the agent's NATIVE wire JSON, NOT the raw core
# Decision. These helpers assert that wire JSON, reconstructed from the old
# expected outputs in fixtures/claude-code/run-fixtures.sh and
# fixtures/codex/run-codex-fixtures.py. They guard that a command-hook fixture
# can NEVER pass while emitting the raw Decision shape: a non-empty output must
# validate against the wire schema and must never carry the Decision-only keys.

# The raw core Decision keys. A command-hook wire output must contain NONE of
# these; if it does, the scanner leaked the Decision instead of shaping it.
_DECISION_ONLY_KEYS = {"surface", "inject_base_rules", "append_correction", "level"}

# The top-level keys the Claude Code / Codex hook schema allows. Any other
# top-level key is an invalid-shape object the runtime rejects.
_WIRE_TOPLEVEL_KEYS = {
    "continue",
    "suppressOutput",
    "stopReason",
    "decision",
    "reason",
    "systemMessage",
    "terminalSequence",
    "permissionDecision",
    "hookSpecificOutput",
}

_WIRE_HOOKSPECIFIC_KEYS = {
    "hookEventName",
    "additionalContext",
    "permissionDecision",
    "permissionDecisionReason",
}

# Old fixture stdout content prefixes (the regexes the deleted harnesses used).
_DENY_REASON_PREFIX = "Blocked. Revise this prose to follow the Communication Rules."
_REISSUE_CONTEXT_PREFIX = "Your previous reply broke the Communication Rules."
_REMINDER_CONTEXT_PREFIX = "Reminder: Follow the Communication Rules"


def _assert_wire_schema(name: str, parsed: dict) -> None:
    """Guard: a non-empty command-hook output is valid wire JSON, not a Decision.

    Fails if any raw Decision-only key appears at the top level, or if a
    top-level / hookSpecificOutput key falls outside the allowed wire set. This
    is the explicit guard that a command-hook fixture can never pass while
    emitting the raw Decision shape.
    """
    leaked = _DECISION_ONLY_KEYS & set(parsed)
    if leaked:
        raise AssertionError(f"{name}: wire output leaked raw Decision keys {sorted(leaked)}: {parsed}")
    unknown = set(parsed) - _WIRE_TOPLEVEL_KEYS
    if unknown:
        raise AssertionError(f"{name}: wire output has non-schema top-level keys {sorted(unknown)}: {parsed}")
    specific = parsed.get("hookSpecificOutput")
    if specific is not None:
        if not isinstance(specific, dict):
            raise AssertionError(f"{name}: hookSpecificOutput must be an object: {parsed}")
        unknown_specific = set(specific) - _WIRE_HOOKSPECIFIC_KEYS
        if unknown_specific:
            raise AssertionError(
                f"{name}: hookSpecificOutput has non-schema keys {sorted(unknown_specific)}: {parsed}"
            )


def expected_wire(event: str, decision: dict) -> dict | None:
    """Map a core decision expectation to the wire output the agent consumes.

    Returns the expected wire dict, or ``None`` when the hook must emit nothing
    (a pass, or a duplicate breach with an empty notice). The dict uses sentinel
    prefix markers for the long reminder / correction / block texts: the caller
    matches those by prefix, mirroring the regex the deleted harnesses used.
    """
    verb = decision["decision"]
    surface = decision.get("surface")
    notice = decision.get("notice", "")

    if verb == "pass":
        return None
    if verb == "remind":
        # SessionStart / SubagentStart reminder as additionalContext under the
        # event name the hook fired on.
        return {
            "hookSpecificOutput": {
                "hookEventName": event,
                "additionalContext": ("PREFIX", _REMINDER_CONTEXT_PREFIX),
            }
        }
    if verb == "re-issue":
        return {
            "hookSpecificOutput": {
                "hookEventName": event,
                "additionalContext": ("PREFIX", _REISSUE_CONTEXT_PREFIX),
            }
        }
    if verb == "yield":
        # Tier B yield: allow with the user-facing notice (verbatim).
        return {
            "hookSpecificOutput": {
                "hookEventName": event,
                "permissionDecision": "allow",
                "permissionDecisionReason": notice,
            }
        }
    if verb == "allow-revise":
        # B1 strike 2+: allow the write to land, the reason carries the RESOLVED
        # B1 revision prompt. ``notice`` here is the raw target the gate placed
        # on the decision (the plugin path asserts it raw); the command agent
        # reason is the resolved prompt the dispatcher built from it, so we match
        # it by the fixed clauses plus the concrete target. A file-tool target
        # yields the path-naming clauses; an empty target (a Bash B1 breach)
        # yields the generic sentence. Either way no literal "{target}" appears.
        target = notice.strip()
        if target:
            reason_match = ("CONTAINS", (_B1_REVISION_CLAUSE, target, _B1_REVISION_TRAILER))
        else:
            reason_match = ("CONTAINS", (_B1_REVISION_GENERIC,))
        return {
            "hookSpecificOutput": {
                "hookEventName": event,
                "permissionDecision": "allow",
                "permissionDecisionReason": reason_match,
            }
        }
    if verb == "block":
        if surface == "tierA":
            # A facing breach emits a systemMessage; a duplicate (empty notice)
            # emits nothing.
            if notice:
                return {"systemMessage": notice}
            return None
        # Tier B gating block: deny with the block message reason. A B2 middle
        # block carries the short nudge as the exact deny reason; the first and
        # penultimate B2 blocks (and every B1 block) re-issue the full rules,
        # matched by the deny-reason prefix.
        nudge = decision.get("block_message")
        if surface == "B2" and nudge:
            reason_match: object = nudge
        else:
            reason_match = ("PREFIX", _DENY_REASON_PREFIX)
        return {
            "hookSpecificOutput": {
                "hookEventName": event,
                "permissionDecision": "deny",
                "permissionDecisionReason": reason_match,
            }
        }
    raise AssertionError(f"unmapped decision verb {verb!r}")


def _wire_value_matches(want: object, got: object) -> bool:
    # A ("PREFIX", text) sentinel matches any string that starts with text; a
    # ("CONTAINS", (sub, ...)) sentinel matches any string containing every
    # substring AND carrying no literal "{target}"; everything else compares for
    # equality (recursing into dicts).
    if isinstance(want, tuple) and len(want) == 2 and want[0] == "PREFIX":
        return isinstance(got, str) and got.startswith(want[1])
    if isinstance(want, tuple) and len(want) == 2 and want[0] == "CONTAINS":
        if not isinstance(got, str) or _TARGET_PLACEHOLDER in got:
            return False
        return all(sub in got for sub in want[1])
    if isinstance(want, dict):
        if not isinstance(got, dict) or set(want) != set(got):
            return False
        return all(_wire_value_matches(want[key], got[key]) for key in want)
    return want == got


def assert_wire(name: str, event: str, stdout: str, decision: dict) -> None:
    """Assert the command-hook stdout matches the expected wire output.

    Reconstructs the expected wire dict from the core decision expectation,
    runs the schema guard on any non-empty output, then compares (prefix-aware)
    against the expectation.
    """
    expected = expected_wire(event, decision)
    output = stdout.strip()
    if expected is None:
        if output:
            raise AssertionError(f"{name} {event}: expected empty wire output, got {output!r}")
        return
    if not output:
        raise AssertionError(f"{name} {event}: expected wire output {expected}, got empty")
    try:
        parsed = json.loads(output)
    except json.JSONDecodeError as error:
        raise AssertionError(f"{name} {event}: non-JSON wire output {output!r}") from error
    if not isinstance(parsed, dict):
        raise AssertionError(f"{name} {event}: wire output not an object: {parsed!r}")
    _assert_wire_schema(f"{name} {event}", parsed)
    if not _wire_value_matches(expected, parsed):
        raise AssertionError(f"{name} {event}: wire mismatch\n  expected {expected}\n  got      {parsed}")


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
        input_text = json.dumps(payload) if payload is not None else materialise(name)
        completed = subprocess.run(
            [sys.executable, str(SCANNER), "--rules", str(RULES), "claude-code", event],
            input=input_text,
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
        # Claude Code is a command-hook agent: assert the WIRE JSON the runtime
        # consumes, not the raw core Decision. The guard inside assert_wire
        # rejects any leaked Decision shape.
        assert_wire(f"claude-code {name}", event, completed.stdout, expected)
        count += 1

    # SessionStart injects the rules reminder as additionalContext; a clean
    # UserPromptSubmit (no pending flag) emits nothing.
    run_case("session-start.json", "SessionStart", _REMIND)
    run_case("user-prompt-submit.json", "UserPromptSubmit", _PASS_TIERA)

    # B1 write: pass, then the hybrid on a shared key. Strike 1 blocks (one
    # cheap attempt before the write lands), strike 2 and every later strike
    # allow the write and ask for an in-place revision naming the file path.
    reset_strikes()
    run_case("pre-tool-use-write-pass.json", "PreToolUse", _PASS_TIERB)
    reset_strikes()
    run_case("pre-tool-use-write-block.json", "PreToolUse", _B1_BLOCK)
    run_case("pre-tool-use-write-block.json", "PreToolUse", _b1_allow_revise("/tmp/status.md"))
    run_case("pre-tool-use-write-block.json", "PreToolUse", _b1_allow_revise("/tmp/status.md"))

    # B1 stable-key regression: three different bodies, one file_path+session.
    # The shared key still walks block then allow-revise, never the old yield.
    reset_strikes()
    run_case("pre-tool-use-write-vary-1-block.json", "PreToolUse", _B1_BLOCK)
    run_case("pre-tool-use-write-vary-2-block.json", "PreToolUse", _b1_allow_revise("/tmp/status.md"))
    run_case("pre-tool-use-write-vary-3-block.json", "PreToolUse", _b1_allow_revise("/tmp/status.md"))

    # A clean pass on a DIFFERENT session (the pass fixture is session-fixture,
    # the vary fixtures are session-vary) does NOT reset the vary key, so the
    # vary count keeps climbing: vary-1 blocks (strike 1), vary-2 allow-revises
    # (strike 2). The clean-scan reset on the SAME key is covered below by the
    # write-block + write-pass group, which shares one session.
    reset_strikes()
    run_case("pre-tool-use-write-vary-1-block.json", "PreToolUse", _B1_BLOCK)
    run_case("pre-tool-use-write-pass.json", "PreToolUse", _PASS_TIERB)
    run_case("pre-tool-use-write-vary-2-block.json", "PreToolUse", _b1_allow_revise("/tmp/status.md"))

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

    # A clean pass on the SAME key resets the counter, so the next breach is
    # strike 1 (deny) again, never a lingering allow-revise. The block then
    # allow-revise before the pass proves the count had climbed; the block after
    # proves the pass reset it.
    reset_strikes()
    run_case("pre-tool-use-write-block.json", "PreToolUse", _B1_BLOCK)
    run_case("pre-tool-use-write-block.json", "PreToolUse", _b1_allow_revise("/tmp/status.md"))
    run_case("pre-tool-use-write-pass.json", "PreToolUse", _PASS_TIERB)
    run_case("pre-tool-use-write-block.json", "PreToolUse", _B1_BLOCK)

    # B2 external MCP post: five-strike cap. Deny 1-4, yield on 5 with the
    # operator notice naming the tool and target. The first and penultimate
    # blocks (strikes 1 and 4) re-issue the full rules; the middle blocks
    # (strikes 2 and 3) carry the short nudge as the deny reason.
    reset_strikes()
    for nudge in (False, True, True, False):
        run_case("pre-tool-use-mcp-post-target-block.json", "PreToolUse", _b2_block(nudge))
    run_case(
        "pre-tool-use-mcp-post-target-block.json",
        "PreToolUse",
        _b2_yield("Rules breach posted: mcp__github__add_issue_comment 42"),
    )

    # The stable B2 key means reworded bodies share one budget; a clean post
    # resets the counter. Strike 1 re-issues the full rules; strike 2 (the
    # reworded body, same budget) is a middle block, so it carries the short
    # nudge. The clean pass resets, so the final breach is strike 1 (full rules).
    reset_strikes()
    run_case("pre-tool-use-mcp-post-block.json", "PreToolUse", _b2_block())
    run_case("pre-tool-use-mcp-post-block-reworded.json", "PreToolUse", _b2_block(nudge=True))
    run_case("pre-tool-use-mcp-post-pass.json", "PreToolUse", _expect("pass", "B2", level="warning"))
    run_case("pre-tool-use-mcp-post-block.json", "PreToolUse", _b2_block())

    # B2 gh-via-Bash: a gh post run through Bash walks the five-strike cap with a
    # notice naming the gh subcommand. The body routes through scan_bash. Full
    # rules on strikes 1 and 4, the short nudge on strikes 2 and 3.
    reset_strikes()
    for nudge in (False, True, True, False):
        run_case("pre-tool-use-bash-gh-post-target-block.json", "PreToolUse", _b2_block(nudge))
    run_case(
        "pre-tool-use-bash-gh-post-target-block.json",
        "PreToolUse",
        _b2_yield("Rules breach posted: gh pr comment"),
    )

    # Env-prefix evasion: a leading "GH_TOKEN=x gh ..." or "FOO=bar printf ..."
    # must NOT hide the command. The env assignment is stripped before the
    # command-name checks, so the gh post still classifies B2 (walks the cap) and
    # the printf write still classifies B1. The banned word is assembled from
    # fragments, never a plain literal.
    _banned_env = "rob" + "ust"

    reset_strikes()
    _env_gh_command = (
        "GH_TOKEN=x gh issue create --repo o/r --title t --body 'a %s body'" % _banned_env
    )

    def _env_gh_post() -> dict:
        return {
            "session_id": "cc-env-gh",
            "tool_name": "Bash",
            "tool_input": {"command": _env_gh_command},
        }

    # The env-prefixed gh post is B2 external: it walks the five-strike cap, not
    # the B1 allow-revise path. Strikes 1 and 4 carry full rules, 2 and 3 the
    # nudge. Strike 5 yields. external_target reads the bare gh subcommand from
    # the raw command string, where the leading token is the env assignment, so
    # the yield target falls back to the tool label "Bash".
    for nudge in (False, True, True, False):
        run_case("env-prefix gh post", "PreToolUse", _b2_block(nudge), payload=_env_gh_post())
    run_case(
        "env-prefix gh post yield",
        "PreToolUse",
        _b2_yield("Rules breach posted: Bash"),
        payload=_env_gh_post(),
    )

    # A clean env-prefixed command passes the gate: no banned word, no breach.
    # The redirect sink survives the env strip, so the command is still read.
    reset_strikes()
    run_case(
        "env-prefix clean",
        "PreToolUse",
        _PASS_TIERB,
        payload={
            "session_id": "cc-env-clean",
            "tool_name": "Bash",
            "tool_input": {"command": "GH_TOKEN=x printf 'a clean line' > /tmp/cc-env-clean.md"},
        },
    )

    # Surface-classifier flag coverage: gh post flags the OLD hand-rolled list
    # missed (``--notes-file`` bare and ``=`` forms, short ``-n``) must classify
    # B2 external and walk the five-strike cap, never fall to B1 allow-revise (the
    # path on which the post executes). No body flag the old list knew is present,
    # so the missing flag alone decides the surface. The cap-walk IS the proof: a
    # misclassified B1 gate would allow-revise on strike 2, not deny across all
    # strikes. The two ``--notes-file`` cases read a missing file, which fails the
    # body scan closed; the close still routes through the chosen surface, so the
    # B2 cap-walk shows the surface caught the flag. The ``-n`` body is scanned
    # inline and carries an assembled banned word, never a plain literal.
    _gh_flag_commands = {
        "gh-notes-file-bare": (
            "gh issue create --repo o/r --notes-file /tmp/cc-nf.md",
            "gh issue create",
        ),
        "gh-notes-file-eq": (
            "gh issue create --repo o/r --notes-file=/tmp/cc-nf.md",
            "gh issue create",
        ),
        "gh-release-short-n": (
            'gh release create v1 -n "a %s body"' % _banned_env,
            "gh release create",
        ),
    }

    def _gh_flag_post(session: str, command: str) -> dict:
        return {
            "session_id": session,
            "tool_name": "Bash",
            "tool_input": {"command": command},
        }

    for label, (command, subcommand) in _gh_flag_commands.items():
        reset_strikes()
        for nudge in (False, True, True, False):
            run_case(
                label,
                "PreToolUse",
                _b2_block(nudge),
                payload=_gh_flag_post("cc-%s" % label, command),
            )
        run_case(
            "%s yield" % label,
            "PreToolUse",
            _b2_yield("Rules breach posted: %s" % subcommand),
            payload=_gh_flag_post("cc-%s" % label, command),
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
            "Your previous reply broke the Communication Rules. Apply them to this reply and every reply that follows. Do not resend or rewrite the previous reply.\n",
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
#   assert_pretooluse_allow_revise        decision=allow-revise, surface=B1, notice
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
        # Codex is a command-hook agent: assert the WIRE JSON the runtime
        # consumes, not the raw core Decision. The guard inside assert_wire
        # rejects any leaked Decision shape.
        assert_wire(f"codex {name}", event, completed.stdout, expected)
        count += 1

    # SessionStart and SubagentStart inject the rules reminder as
    # additionalContext under their own event name; a clean UserPromptSubmit
    # (no pending flag) emits nothing.
    run_case("session-start.json", "SessionStart", _REMIND)
    run_case("subagent-start.json", "SubagentStart", _REMIND)
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

    # B1 hybrid on a shared session+turn+tool+path key: block on strike 1, then
    # allow-revise on strike 2+ naming the file path (here "note.txt").
    reset_strikes()
    run_case("pre-tool-use-write-blocked.json", "PreToolUse", _B1_BLOCK)
    run_case("pre-tool-use-write-blocked.json", "PreToolUse", _b1_allow_revise("note.txt"))
    run_case("pre-tool-use-write-blocked.json", "PreToolUse", _b1_allow_revise("note.txt"))

    # B1 apply_patch keys per-file from the patch body. Codex's apply_patch
    # carries no file_path key; pre_tool_use_target reads the target from the
    # "*** Add File:" marker. Strike 1 blocks; strike 2 allow-revises naming that
    # file. A SECOND patch to a DIFFERENT file is its own strike 1 (deny), proving
    # the patch path is in the key. Before the per-file fix, apply_patch collapsed
    # to one coarse session+turn+tool key: the first patch blocked and every later
    # patch (any file) landed. The U+2014 payload keeps each patch a breach.
    reset_strikes()
    base_patch = json.loads((CODEX_FX / "pre-tool-use-apply-patch-blocked.json").read_text(encoding="utf-8"))

    def _patch_to(path: str) -> dict:
        payload = json.loads(json.dumps(base_patch))
        payload["tool_input"]["command"] = (
            "*** Begin Patch\n*** Add File: %s\n+Blocked\u2014payload text.\n*** End Patch\n" % path
        )
        return payload

    patch_a = _patch_to("note-a.txt")
    patch_b = _patch_to("note-b.txt")
    run_case("apply_patch a strike 1", "PreToolUse", _B1_BLOCK, payload=patch_a)
    run_case("apply_patch a strike 2", "PreToolUse", _b1_allow_revise("note-a.txt"), payload=patch_a)
    # A DIFFERENT patched file is its own strike 1 (deny), not a shared
    # allow-revise. A coarse key would allow-revise this second file instead.
    run_case("apply_patch b strike 1", "PreToolUse", _B1_BLOCK, payload=patch_b)

    # Codex per-turn reset: the same write breach on a NEW turn id starts a fresh
    # B1 count (strike 1, deny), proving the turn is in the key. Within turn-A the
    # hybrid walks block then allow-revise; turn-B resets to a fresh block. The
    # write-blocked fixture path is note.txt; vary the turn_id to a second turn.
    reset_strikes()
    base_write = json.loads((CODEX_FX / "pre-tool-use-write-blocked.json").read_text(encoding="utf-8"))
    turn_one = dict(base_write, turn_id="turn-A")
    turn_two = dict(base_write, turn_id="turn-B")
    run_case("write turn-A strike 1", "PreToolUse", _B1_BLOCK, payload=turn_one)
    run_case("write turn-A strike 2", "PreToolUse", _b1_allow_revise("note.txt"), payload=turn_one)
    # A different turn id resets to strike 1 (deny) rather than continuing to
    # allow-revise, proving the turn id is part of the key.
    run_case("write turn-B strike 1", "PreToolUse", _B1_BLOCK, payload=turn_two)

    # B1 stable-key regression: three different bodies, one file_path+session+turn.
    # The shared key walks block then allow-revise, never the old yield.
    reset_strikes()
    run_case("pre-tool-use-write-vary-1-blocked.json", "PreToolUse", _B1_BLOCK)
    run_case("pre-tool-use-write-vary-2-blocked.json", "PreToolUse", _b1_allow_revise("note.txt"))
    run_case("pre-tool-use-write-vary-3-blocked.json", "PreToolUse", _b1_allow_revise("note.txt"))

    # A clean pass on the same key resets the counter.
    reset_strikes()
    run_case("pre-tool-use-write-vary-1-blocked.json", "PreToolUse", _B1_BLOCK)
    run_case("pre-tool-use-write-vary-clean.json", "PreToolUse", _PASS_TIERB)
    run_case("pre-tool-use-write-vary-2-blocked.json", "PreToolUse", _B1_BLOCK)

    # B2 external MCP post: five-strike cap. Deny 1-4, yield on 5 with the
    # operator notice naming the tool and target. Reworded body shares one budget.
    # Full rules on strikes 1 and 4, the short nudge on strikes 2 and 3.
    reset_strikes()
    run_case("pre-tool-use-post-target-blocked.json", "PreToolUse", _b2_block())
    run_case("pre-tool-use-post-reworded-blocked.json", "PreToolUse", _b2_block(nudge=True))
    run_case("pre-tool-use-post-target-blocked.json", "PreToolUse", _b2_block(nudge=True))
    run_case("pre-tool-use-post-target-blocked.json", "PreToolUse", _b2_block())
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
    # notice naming the gh subcommand. The body routes through scan_bash. Full
    # rules on strikes 1 and 4, the short nudge on strikes 2 and 3.
    reset_strikes()
    for nudge in (False, True, True, False):
        run_case("pre-tool-use-bash-gh-post-blocked.json", "PreToolUse", _b2_block(nudge))
    run_case(
        "pre-tool-use-bash-gh-post-blocked.json",
        "PreToolUse",
        _b2_yield("Rules breach posted: gh pr comment"),
    )

    # Wrapped LOCAL write: a banned word hidden inside a "bash -lc \"...\"" wrapper
    # must still block, and the strike must key per-file on the inner prose sink.
    # Two different wrapped sinks each get their OWN one-block budget, so both are
    # strike 1 (deny). Before the unwrap fix the wrapper hid the redirect and the
    # write slipped past unscanned. The banned word is assembled from fragments,
    # never a plain literal.
    reset_strikes()
    _banned_local = "del" + "ve"

    def _wrapped_local_bash(sink: str) -> dict:
        command = 'bash -lc "printf \'%s here\' > %s"' % (_banned_local, sink)
        return {
            "session_id": "wrapped-local",
            "turn_id": "wrap-turn",
            "tool_name": "Bash",
            "tool_input": {"command": command},
        }

    run_case("wrapped local sink A", "PreToolUse", _B1_BLOCK, payload=_wrapped_local_bash("wrap-a.md"))
    # A DIFFERENT wrapped sink in the same session+turn is its own strike 1, not a
    # shared allow-revise. The inner sink is the per-file key.
    run_case("wrapped local sink B", "PreToolUse", _B1_BLOCK, payload=_wrapped_local_bash("wrap-b.md"))

    # Wrapped gh post: a "bash -lc \"gh issue create --body ...\"" wrapper must
    # classify as B2 external (hard five-strike block), never B1 allow-revise. The
    # body routes through scan_bash and detects the banned word; the surface stays
    # external so it walks the five-strike cap and yields on strike 5.
    reset_strikes()
    _wrapped_gh_command = 'bash -lc "gh issue create --title hi --body \'we %s here\'"' % _banned_local

    def _wrapped_gh_post() -> dict:
        return {
            "session_id": "wrapped-gh",
            "turn_id": "wrap-gh-turn",
            "tool_name": "Bash",
            "tool_input": {"command": _wrapped_gh_command},
        }

    for nudge in (False, True, True, False):
        run_case("wrapped gh post", "PreToolUse", _b2_block(nudge), payload=_wrapped_gh_post())
    # The B2 yield names the operator target. A wrapped command exposes no bare gh
    # subcommand, so the target falls back to the tool label "Bash". The point of
    # this case is the SURFACE (B2 hard block, not B1 allow-revise), not the label.
    run_case(
        "wrapped gh post yield",
        "PreToolUse",
        _b2_yield("Rules breach posted: Bash"),
        payload=_wrapped_gh_post(),
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

    # Env-prefix evasion: a leading "GH_TOKEN=x gh ..." or "FOO=bar printf ..."
    # must NOT hide the command. The env assignment is stripped before the
    # command-name checks, so the gh post still classifies B2 (walks the cap) and
    # the printf write still classifies B1. The banned word is assembled from
    # fragments, never a plain literal.
    _banned_env = "rob" + "ust"

    reset_strikes()
    _env_gh_command = (
        "GH_TOKEN=x gh issue create --repo o/r --title t --body 'a %s body'" % _banned_env
    )

    def _env_gh_post() -> dict:
        return {
            "session_id": "env-gh",
            "turn_id": "env-gh-turn",
            "tool_name": "Bash",
            "tool_input": {"command": _env_gh_command},
        }

    # The env-prefixed gh post is B2 external: it walks the five-strike cap, not
    # the B1 allow-revise path. Strikes 1 and 4 carry full rules, 2 and 3 the
    # nudge. Strike 5 yields. The wrapped command exposes a bare gh subcommand
    # after the env strip, so the target names the subcommand.
    for nudge in (False, True, True, False):
        run_case("env-prefix gh post", "PreToolUse", _b2_block(nudge), payload=_env_gh_post())
    # The B2 yield names the operator target. external_target reads the bare gh
    # subcommand from the raw command string, where the leading token is the env
    # assignment, so it falls back to the tool label "Bash". The point of this
    # case is the SURFACE (B2 hard block, not B1 allow-revise), not the label.
    run_case(
        "env-prefix gh post yield",
        "PreToolUse",
        _b2_yield("Rules breach posted: Bash"),
        payload=_env_gh_post(),
    )

    # The env-prefixed printf write is B1 local: the redirect sink survives the
    # env strip, so the breach is caught and keyed per-file on the sink.
    reset_strikes()
    _env_write_command = "FOO=bar printf 'a %s line' > /tmp/env-x.md" % _banned_env

    def _env_write() -> dict:
        return {
            "session_id": "env-write",
            "turn_id": "env-write-turn",
            "tool_name": "Bash",
            "tool_input": {"command": _env_write_command},
        }

    run_case("env-prefix write strike 1", "PreToolUse", _B1_BLOCK, payload=_env_write())
    run_case(
        "env-prefix write strike 2",
        "PreToolUse",
        _b1_allow_revise("/tmp/env-x.md"),
        payload=_env_write(),
    )

    # A clean env-prefixed command passes the gate: no banned word, no breach.
    reset_strikes()
    run_case(
        "env-prefix clean",
        "PreToolUse",
        _PASS_TIERB,
        payload={
            "session_id": "env-clean",
            "turn_id": "env-clean-turn",
            "tool_name": "Bash",
            "tool_input": {"command": "GH_TOKEN=x printf 'a clean line' > /tmp/env-clean.md"},
        },
    )

    # apply_patch added-text scanning. Codex scans the ADDED ("+") lines only.
    rules_body = RULES.read_text(encoding="utf-8").strip()

    # Writing the FULL canonical rules text via apply_patch is a disclosure, not a
    # breach: the added text equals the canonical rules, so the exemption fires
    # and the gate passes. Before the added-text fix, Codex scanned the raw patch
    # (markers and "+" prefixes), never byte-matched the exemption, and the banned
    # words listed in the rules triggered a false block.
    reset_strikes()
    rules_patch = (
        "*** Begin Patch\n*** Add File: /tmp/rules.md\n"
        + "".join("+%s\n" % line for line in rules_body.split("\n"))
        + "*** End Patch\n"
    )
    run_case(
        "apply_patch full rules disclosure",
        "PreToolUse",
        _PASS_TIERB,
        payload={
            "session_id": "patch-rules",
            "turn_id": "patch-rules-turn",
            "tool_name": "apply_patch",
            "tool_input": {"command": rules_patch},
        },
    )

    # A banned word on an ADDED line blocks (B1 local, keyed on the patch target).
    # The banned word is assembled from fragments, never a plain literal.
    _banned_patch = "del" + "ve"
    reset_strikes()
    added_breach_patch = (
        "*** Begin Patch\n*** Add File: /tmp/breach.md\n"
        "+We %s into this topic.\n"
        "*** End Patch\n" % _banned_patch
    )
    run_case(
        "apply_patch added breach",
        "PreToolUse",
        _B1_BLOCK,
        payload={
            "session_id": "patch-breach",
            "turn_id": "patch-breach-turn",
            "tool_name": "apply_patch",
            "tool_input": {"command": added_breach_patch},
        },
    )

    # A banned word that sits ONLY on a context line or a removed ("-") line, not
    # an added ("+") line, passes: added-text-only scanning never sees it. This
    # proves the scan reads the "+" lines, not the raw patch body.
    reset_strikes()
    context_only_patch = (
        "*** Begin Patch\n*** Update File: /tmp/ctx.md\n"
        " We %s into this old context line.\n"
        "-We %s on the removed line.\n"
        "+A clean added line.\n"
        "*** End Patch\n" % (_banned_patch, _banned_patch)
    )
    run_case(
        "apply_patch banned only in context or removed",
        "PreToolUse",
        _PASS_TIERB,
        payload={
            "session_id": "patch-ctx",
            "turn_id": "patch-ctx-turn",
            "tool_name": "apply_patch",
            "tool_input": {"command": context_only_patch},
        },
    )

    return count


def codex_agent_cases() -> int:
    """Set up the temp strike/reissue/correction env and run the codex cases."""
    with tempfile.TemporaryDirectory(prefix="tripwire-codex-") as temp_dir:
        strike_dir = str(Path(temp_dir) / "codex-retries")
        Path(strike_dir).mkdir(parents=True, exist_ok=True)
        correction = Path(temp_dir) / "correction-prompt.md"
        correction.write_text(
            "Your previous reply broke the Communication Rules. Apply them to this reply and every reply that follows. Do not resend or rewrite the previous reply.\n",
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
#   tool_call strike 2+ allow-revise (B1) decision=allow-revise, surface=B1, target notice
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
        _assert_no_target_placeholder(f"pi {name} {event}", record.get("notice"))
        _assert_record_fields(f"pi {name} {event}", record, expected)
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

    # B1 hybrid on a shared session+tool+path key (write): block on strike 1,
    # then allow-revise on strike 2+ carrying the raw target (here "notes.md")
    # for the shim to resolve into the revision prompt.
    reset_strikes()
    run_case("tool-call-write-blocked.json", "tool_call", _B1_BLOCK)
    run_case("tool-call-write-blocked.json", "tool_call", _b1_allow_revise("notes.md"))
    run_case("tool-call-write-blocked.json", "tool_call", _b1_allow_revise("notes.md"))

    # A clean pass on the same key resets the counter, so the next breach is
    # strike 1 (deny), never the yield.
    reset_strikes()
    run_case("tool-call-write-blocked.json", "tool_call", _B1_BLOCK)
    run_case("tool-call-write-clean.json", "tool_call", _PASS_TIERB)
    run_case("tool-call-write-blocked.json", "tool_call", _B1_BLOCK)

    # B2 external mcp post: five-strike cap. Deny 1-4, yield on 5 with the
    # operator notice naming the tool and target. The first and penultimate
    # blocks (strikes 1 and 4) re-issue the full rules in ``block_message``; the
    # middle blocks (strikes 2 and 3) carry the short nudge there, with an empty
    # ``notice`` (the dispatcher promoted the nudge to the block message).
    reset_strikes()
    for nudge in (False, True, True, False):
        run_case("tool-call-mcp-post-blocked.json", "tool_call", _b2_block(nudge))
    run_case(
        "tool-call-mcp-post-blocked.json",
        "tool_call",
        _b2_yield("Rules breach posted: mcp__linear__create_comment ISS-1"),
    )

    # Env-prefix evasion: a leading "GH_TOKEN=x gh ..." or "FOO=bar printf ..."
    # must NOT hide the command. The env assignment is stripped before the
    # leading-token check, so the gh post still classifies B2 (walks the cap) and
    # the printf write still classifies B1. The banned word is assembled from
    # fragments, never a plain literal.
    _banned_env = "rob" + "ust"

    reset_strikes()
    _env_gh_command = (
        "GH_TOKEN=x gh issue create --repo o/r --title t --body 'a %s body'" % _banned_env
    )

    def _env_gh_post() -> dict:
        return {
            "session_id": "pi-env-gh",
            "type": "tool_call",
            "toolName": "bash",
            "toolCallId": "env-gh-call",
            "input": {"command": _env_gh_command},
        }

    # The env-prefixed gh post is B2 external: it walks the five-strike cap, not
    # the B1 allow-revise path. The bash tool with a command has no structured
    # identifier, so the yield target falls back to the tool name "bash".
    for nudge in (False, True, True, False):
        run_case("env-prefix gh post", "tool_call", _b2_block(nudge), payload=_env_gh_post())
    run_case(
        "env-prefix gh post yield",
        "tool_call",
        _b2_yield("Rules breach posted: bash"),
        payload=_env_gh_post(),
    )

    # A clean env-prefixed command passes the gate: no banned word, no breach.
    # The redirect sink survives the env strip, so the command is still read.
    reset_strikes()
    run_case(
        "env-prefix clean",
        "tool_call",
        _PASS_TIERB,
        payload={
            "session_id": "pi-env-clean",
            "type": "tool_call",
            "toolName": "bash",
            "toolCallId": "env-clean-call",
            "input": {"command": "GH_TOKEN=x printf 'a clean line' > /tmp/pi-env-clean.md"},
        },
    )

    # Surface-classifier flag coverage: the same gh post flags the OLD claude-code
    # and codex list missed (``--notes-file`` bare and ``=`` forms, short ``-n``)
    # must classify B2 external and walk the five-strike cap, never fall to B1
    # allow-revise. Pi already classifies any gh command external by its leading
    # token, so these guard that the body path holds at B2 here. The two
    # ``--notes-file`` cases read a missing file, which fails the body scan closed
    # to B2; the ``-n`` body is scanned inline and carries an assembled banned
    # word, never a plain literal. The bash tool exposes no structured identifier,
    # so the yield target is the tool name.
    _gh_flag_commands = {
        "gh-notes-file-bare": ("gh issue create --repo o/r --notes-file /tmp/pi-nf.md"),
        "gh-notes-file-eq": ("gh issue create --repo o/r --notes-file=/tmp/pi-nf.md"),
        "gh-release-short-n": ('gh release create v1 -n "a %s body"' % _banned_env),
    }

    def _gh_flag_post(session: str, command: str) -> dict:
        return {
            "session_id": session,
            "type": "tool_call",
            "toolName": "bash",
            "toolCallId": "%s-call" % session,
            "input": {"command": command},
        }

    for label, command in _gh_flag_commands.items():
        reset_strikes()
        for nudge in (False, True, True, False):
            run_case(
                label,
                "tool_call",
                _b2_block(nudge),
                payload=_gh_flag_post("pi-%s" % label, command),
            )
        run_case(
            "%s yield" % label,
            "tool_call",
            _b2_yield("Rules breach posted: bash"),
            payload=_gh_flag_post("pi-%s" % label, command),
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
            "Your previous reply broke the Communication Rules. Apply them to this reply and every reply that follows. Do not resend or rewrite the previous reply.\n",
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
#   tool strike 2+ allow-revise (plugin B1) decision=allow-revise, surface=B1, target notice
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
        _assert_no_target_placeholder(f"opencode {name} {event}", record.get("notice"))
        _assert_record_fields(f"opencode {name} {event}", record, expected)
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

    # B1 hybrid on a shared session+tool+path key (write): block on strike 1,
    # then allow-revise on strike 2+ carrying the raw target (here "notes.md")
    # for the shim to resolve into the revision prompt.
    reset_strikes()
    run_case("tool-write-blocked.json", "tool.execute.before", _B1_BLOCK)
    run_case("tool-write-blocked.json", "tool.execute.before", _b1_allow_revise("notes.md"))
    run_case("tool-write-blocked.json", "tool.execute.before", _b1_allow_revise("notes.md"))

    # A clean pass on the same key resets the counter, so the next breach is
    # strike 1 (deny), never the yield.
    reset_strikes()
    run_case("tool-write-blocked.json", "tool.execute.before", _B1_BLOCK)
    run_case("tool-write-clean.json", "tool.execute.before", _PASS_TIERB)
    run_case("tool-write-blocked.json", "tool.execute.before", _B1_BLOCK)

    # B2 external post: five-strike cap. Deny 1-4, yield on 5 with the operator
    # notice naming the tool and target. The gh-api-safe post fixture has a
    # command (no structured identifier), so the target falls back to the tool.
    # Full rules on strikes 1 and 4, the short nudge on strikes 2 and 3.
    reset_strikes()
    for nudge in (False, True, True, False):
        run_case("tool-post-blocked.json", "tool.execute.before", _b2_block(nudge))
    run_case(
        "tool-post-blocked.json",
        "tool.execute.before",
        _b2_yield("Rules breach posted: gh-api-safe"),
    )

    # Wrapped LOCAL write: a banned word hidden inside a "bash -lc \"...\"" wrapper
    # must still block, and the strike must key per-file on the inner prose sink.
    # Two different wrapped sinks each get their OWN one-block budget, so both are
    # strike 1 (deny). Before the unwrap fix the wrapper hid the redirect and the
    # write slipped past unscanned. The banned word is assembled from fragments.
    reset_strikes()
    _banned_oc = "del" + "ve"

    def _wrapped_local_bash(sink: str) -> dict:
        command = 'bash -lc "printf \'%s here\' > %s"' % (_banned_oc, sink)
        return {
            "session_id": "oc-wrapped-local",
            "event": "tool.execute.before",
            "tool": {"name": "bash"},
            "args": {"command": command},
        }

    run_case("wrapped local sink A", "tool.execute.before", _B1_BLOCK, payload=_wrapped_local_bash("wrap-a.md"))
    # A DIFFERENT wrapped sink in the same session is its own strike 1, not a
    # shared allow-revise. The inner sink is the per-file key.
    run_case("wrapped local sink B", "tool.execute.before", _B1_BLOCK, payload=_wrapped_local_bash("wrap-b.md"))

    # Wrapped gh post: a "bash -lc \"gh issue create --body ...\"" wrapper must
    # classify as B2 external (hard five-strike block), never B1 allow-revise. The
    # body routes through scan_bash and detects the banned word; the surface stays
    # external so it walks the five-strike cap and yields on strike 5.
    reset_strikes()
    _wrapped_gh = 'bash -lc "gh issue create --title hi --body \'we %s here\'"' % _banned_oc

    def _wrapped_gh_post() -> dict:
        return {
            "session_id": "oc-wrapped-gh",
            "event": "tool.execute.before",
            "tool": {"name": "bash"},
            "args": {"command": _wrapped_gh},
        }

    for nudge in (False, True, True, False):
        run_case("wrapped gh post", "tool.execute.before", _b2_block(nudge), payload=_wrapped_gh_post())
    # The B2 yield names the operator target. The bash tool with a wrapped command
    # has no structured identifier, so the target falls back to the tool name
    # "bash". The point is the SURFACE (B2 hard block, not B1 allow-revise).
    run_case(
        "wrapped gh post yield",
        "tool.execute.before",
        _b2_yield("Rules breach posted: bash"),
        payload=_wrapped_gh_post(),
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

    # Env-prefix evasion: a leading "GH_TOKEN=x gh ..." or "FOO=bar printf ..."
    # must NOT hide the command. The env assignment is stripped before the
    # command-name checks, so the gh post stays B2 (walks the cap) and the printf
    # write stays B1. The banned word is assembled from fragments.
    _banned_env = "rob" + "ust"

    reset_strikes()
    _env_gh = "GH_TOKEN=x gh issue create --repo o/r --title t --body 'a %s body'" % _banned_env

    def _env_gh_post() -> dict:
        return {
            "session_id": "oc-env-gh",
            "event": "tool.execute.before",
            "tool": {"name": "bash"},
            "args": {"command": _env_gh},
        }

    # The env-prefixed gh post is B2 external: it walks the five-strike cap, not
    # the B1 allow-revise path. The bash tool with a command has no structured
    # identifier, so the yield target falls back to the tool name "bash".
    for nudge in (False, True, True, False):
        run_case("env-prefix gh post", "tool.execute.before", _b2_block(nudge), payload=_env_gh_post())
    run_case(
        "env-prefix gh post yield",
        "tool.execute.before",
        _b2_yield("Rules breach posted: bash"),
        payload=_env_gh_post(),
    )

    # The env-prefixed printf write is B1 local: the redirect sink survives the
    # env strip, so the breach is caught and keyed per-file on the sink.
    reset_strikes()
    _env_write = "FOO=bar printf 'a %s line' > /tmp/oc-env-x.md" % _banned_env

    def _env_write_payload() -> dict:
        return {
            "session_id": "oc-env-write",
            "event": "tool.execute.before",
            "tool": {"name": "bash"},
            "args": {"command": _env_write},
        }

    run_case("env-prefix write strike 1", "tool.execute.before", _B1_BLOCK, payload=_env_write_payload())
    run_case(
        "env-prefix write strike 2",
        "tool.execute.before",
        _b1_allow_revise("/tmp/oc-env-x.md"),
        payload=_env_write_payload(),
    )

    # A clean env-prefixed command passes the gate.
    reset_strikes()
    run_case(
        "env-prefix clean",
        "tool.execute.before",
        _PASS_TIERB,
        payload={
            "session_id": "oc-env-clean",
            "event": "tool.execute.before",
            "tool": {"name": "bash"},
            "args": {"command": "GH_TOKEN=x printf 'a clean line' > /tmp/oc-env-clean.md"},
        },
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
            "Your previous reply broke the Communication Rules. Apply them to this reply and every reply that follows. Do not resend or rewrite the previous reply.\n",
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
