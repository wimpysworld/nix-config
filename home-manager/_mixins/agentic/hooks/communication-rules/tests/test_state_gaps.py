#!/usr/bin/env python3
"""Cross-agent gap tests for the core state machine (proposal tests 7, 8, 9).

These close three named coverage gaps the per-adapter fixtures miss:

- gh-via-Bash B2 for Pi: a ``gh pr comment`` Bash tool_call walks the
  five-strike external cap with the gh notice. Pi only had a single-shot case.
- Tier A extraction-failure for OpenCode (final and subagent): an unresolvable
  facing surface must re-issue, not hard-block.
- Per-agent broken-scanner fail-closed on a gating surface (the 0b080fb8 fix,
  reimplemented in ``core/state.py``): a broken scanner returns block or yield,
  never pass.

Each gating step spawns ``scanner.py <agent> <event>`` fresh with a temp strike
dir via env, mirroring the multi-process pattern in
``run-scanner-fixtures.py``. The OpenCode facing extraction-failure case now
drives the real OpenCode extractor through the dispatcher CLI end to end
(Phase 7.1 landed the extractor), replacing the earlier state-level assertion.

The breach body must contain a hard-gate banned term to trip detection. The
source file holds no literal banned term (that would block its own write under
the tripwire); it reads the canonical term from the loaded policy at runtime.

Stdlib only. British English in comments.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCANNER = ROOT / "scanner.py"
RULES = ROOT / "communication-rules.md"

sys.path.insert(0, str(ROOT))
from core.config import DEFAULT_POLICY  # noqa: E402

# A canonical hard-gate banned term, read from the policy so this file holds no
# literal banned word. Used in the breach body so detection trips.
BANNED_TERM = DEFAULT_POLICY["hardGateBannedTerms"][0]

# A gh post in the Pi tool_call shape, with a banned word in the body. Pi's bash
# tool is "bash" with the command under "input", and its event arrives on the
# tool_call handler. The first token is gh and the body flag makes it external
# (B2), so it walks the five-strike cap. The real Pi extractor (Phase 6) routes
# this, where the Phase 3 stub keyed on PreToolUse.
PI_GH_POST_EVENT = {
    "session_id": "gap-session",
    "type": "tool_call",
    "toolName": "bash",
    "toolCallId": "call-gh-post",
    "input": {"command": f'gh pr comment 1 --body "Please {BANNED_TERM} this"'},
}

# A clean local Bash command. With a broken scanner (no readable rules) it cannot
# be decided, so the gating surface must fail closed rather than pass.
CLEAN_LOCAL_EVENT = {
    "session_id": "gap-session",
    "tool_name": "Bash",
    "tool_input": {"command": "echo hello"},
}

# The same clean local Bash command in the Pi tool_call shape. Pi's gating
# surface is the tool_call handler, not PreToolUse.
PI_CLEAN_LOCAL_EVENT = {
    "session_id": "gap-session",
    "type": "tool_call",
    "toolName": "bash",
    "toolCallId": "call-clean",
    "input": {"command": "echo hello"},
}

# The same clean local Bash command in the OpenCode tool.execute.before shape.
# OpenCode's gating surface is the tool.execute.before event with the command
# under "args".
OPENCODE_CLEAN_LOCAL_EVENT = {
    "session_id": "gap-session",
    "event": "tool.execute.before",
    "tool": {"name": "bash"},
    "args": {"command": "echo hello"},
}

# The B2 external yield notice the state machine bakes. The Pi extractor has no
# gh-subcommand target, so the notice falls back to the Pi tool name ("bash"),
# mirroring the old Pi extension's externalTarget.
B2_GH_NOTICE = "Rules breach posted: bash"

# Per-agent strike-dir env names, from core/state.py:_strike_dir. Pointing every
# name at the same temp dir keeps the spawn agent-agnostic.
STRIKE_DIR_ENVS = (
    "TRIPWIRE_CLAUDE_CODE_STRIKE_DIR",
    "TRIPWIRE_RETRY_DIR",
    "TRIPWIRE_PI_STRIKE_DIR",
    "TRIPWIRE_OPENCODE_STRIKE_DIR",
    "TRIPWIRE_STRIKE_DIR",
)


def run_dispatch(
    agent: str,
    event: str,
    payload: dict,
    strike_dir: str,
    rules: str | None = None,
) -> dict:
    """Spawn ``scanner.py <agent> <event>`` fresh and return its decision dict.

    ``rules`` defaults to the real rules file. Pass an unreadable path to model a
    broken scanner (``load_config`` returns ``None``, the fail-closed case).
    """
    env = dict(os.environ)
    for name in STRIKE_DIR_ENVS:
        env[name] = strike_dir
    args = [sys.executable, str(SCANNER), agent, event]
    if rules is not None:
        args += ["--rules", rules]
    completed = subprocess.run(
        args,
        input=json.dumps(payload),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        env=env,
    )
    if completed.returncode != 0:
        raise AssertionError(
            f"{agent} {event}: non-zero exit {completed.returncode}\n"
            f"stderr: {completed.stderr.strip()}"
        )
    try:
        return json.loads(completed.stdout.strip())
    except json.JSONDecodeError as exc:
        raise AssertionError(
            f"{agent} {event}: bad decision JSON {completed.stdout!r}"
        ) from exc


def expect(label: str, result: dict, **fields: object) -> None:
    """Assert each named field of the decision equals the expected value."""
    for key, want in fields.items():
        got = result.get(key)
        if got != want:
            raise AssertionError(
                f"{label}: expected {key}={want!r}, got {got!r} (full: {result})"
            )


def test_pi_gh_via_bash_b2_cap() -> int:
    """Proposal test 7: a Pi gh-via-Bash post walks the B2 five-strike cap.

    Four blocks at surface B2, then a yield on the fifth carrying the gh notice
    and level error. (Pi had only a single-shot case before.)

    Drives the real Pi extractor via its ``tool_call`` handler and Pi event
    shape. The Phase 3 version drove ``PreToolUse`` against the event-agnostic
    stub; the real extractor routes ``tool_call``, so the event moves to the Pi
    shape. The cap, surface, level, and gh notice are unchanged in substance.
    """
    with tempfile.TemporaryDirectory(prefix="tripwire-gap-pi-b2-") as strike_dir:
        for strike in range(1, 5):
            decision = run_dispatch(
                "pi", "tool_call", PI_GH_POST_EVENT, strike_dir, rules=str(RULES)
            )
            expect(
                f"pi gh-via-bash strike {strike}",
                decision,
                decision="block",
                surface="B2",
                level="error",
            )
        decision = run_dispatch(
            "pi", "tool_call", PI_GH_POST_EVENT, strike_dir, rules=str(RULES)
        )
        expect(
            "pi gh-via-bash yield",
            decision,
            decision="yield",
            surface="B2",
            level="error",
            notice=B2_GH_NOTICE,
        )
    return 1


def test_opencode_extraction_failure_reissues() -> int:
    """Proposal test 8: an OpenCode facing extraction-failure re-issues, not blocks.

    Now driven END TO END through the real OpenCode extractor and the dispatcher
    CLI (Phase 7.1). A recognised display surface (``message.final`` /
    ``subagent.final``) whose body cannot be resolved is a Tier A extraction
    failure: the extractor tags it ``unresolved`` on the facing event, and the
    state machine fails OPEN to re-issue. So the decision is a Tier A facing
    block (it sets the pending-reissue flag and carries the facing notice for the
    next turn), never a hard tool block or yield.

    The contract:

    - final extraction failure -> decision block, surface tierA, with a facing
      notice and the pending-reissue flag written.
    - subagent extraction failure -> same.

    A reachable hard block (surface B1/B2) or a yield would be a regression; the
    test asserts the facing surface and that the flag was set so the next turn
    re-issues.
    """
    checks = 0
    # An empty display payload: the surface is named but the body cannot be
    # resolved, so the extractor reports a Tier A extraction failure.
    events = {
        "final": ("message.final", "final"),
        "subagent": ("subagent.final", "subagent"),
    }
    for label, (event, surface_value) in events.items():
        with tempfile.TemporaryDirectory(prefix=f"tripwire-gap-oc-{label}-") as temp_dir:
            reissue_dir = str(Path(temp_dir) / "reissue")
            env_name = "TRIPWIRE_OPENCODE_REISSUE_DIR"
            previous = os.environ.get(env_name)
            os.environ[env_name] = reissue_dir
            try:
                session = f"oc-{label}"
                payload = {"event": event, "surface": surface_value, "session_id": session}
                # Use a temp strike dir; the facing path never touches it, but
                # run_dispatch points every strike env at one dir for hygiene.
                with tempfile.TemporaryDirectory(prefix=f"tripwire-gap-oc-{label}-strike-") as strike_dir:
                    decision = run_dispatch(
                        "opencode", event, payload, strike_dir, rules=str(RULES)
                    )
                # A Tier A extraction failure must re-issue, never hard block or
                # yield. The decision is a Tier A facing block carrying the notice.
                if decision.get("decision") == "yield" or (
                    decision.get("decision") == "block" and decision.get("surface") != "tierA"
                ):
                    raise AssertionError(
                        f"opencode {label} facing: extraction failure must not "
                        f"hard-block, got {decision.get('decision')}/{decision.get('surface')} "
                        f"(full: {decision})"
                    )
                expect(
                    f"opencode {label} facing extraction failure",
                    decision,
                    decision="block",
                    surface="tierA",
                    level="warning",
                )
                if not decision.get("notice"):
                    raise AssertionError(
                        f"opencode {label} facing: expected a facing re-issue notice, got empty"
                    )
                checks += 1

                # The facing breach wrote the pending-reissue flag, so the next
                # turn would re-issue. Verify the flag landed on disk.
                flags = list(Path(reissue_dir).glob("*.flag"))
                if not flags:
                    raise AssertionError(
                        f"opencode {label} facing: no pending-reissue flag written under {reissue_dir}"
                    )
                checks += 1
            finally:
                if previous is None:
                    os.environ.pop(env_name, None)
                else:
                    os.environ[env_name] = previous

    return checks


def test_per_agent_fail_closed_on_gating_surface() -> int:
    """Proposal test 9: a broken scanner on a gating surface fails closed.

    One case per agent. A broken scanner (unreadable rules -> config None) on a
    local Bash gate must return block or yield, NEVER pass. This is the 0b080fb8
    fix, reimplemented in core/state.py.
    """
    checks = 0
    # Each agent's gating surface and event shape. The real Pi and OpenCode
    # extractors gate on their own handlers (tool_call, tool.execute.before); the
    # command agents gate on PreToolUse.
    gating = {
        "claude-code": ("PreToolUse", CLEAN_LOCAL_EVENT),
        "codex": ("PreToolUse", CLEAN_LOCAL_EVENT),
        "pi": ("tool_call", PI_CLEAN_LOCAL_EVENT),
        "opencode": ("tool.execute.before", OPENCODE_CLEAN_LOCAL_EVENT),
    }
    for agent, (event, payload) in gating.items():
        with tempfile.TemporaryDirectory(prefix=f"tripwire-gap-fc-{agent}-") as strike_dir:
            decision = run_dispatch(
                agent,
                event,
                payload,
                strike_dir,
                rules="/nonexistent/broken-rules.md",
            )
            verb = decision.get("decision")
            if verb not in {"block", "yield"}:
                raise AssertionError(
                    f"{agent} fail-closed: a broken scanner on a gating surface "
                    f"must block or yield, got {verb!r} (full: {decision})"
                )
        checks += 1
    return checks


def main() -> int:
    total = 0
    total += test_pi_gh_via_bash_b2_cap()
    total += test_opencode_extraction_failure_reissues()
    total += test_per_agent_fail_closed_on_gating_surface()
    print(f"state gap checks passed: {total}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
