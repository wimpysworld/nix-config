#!/usr/bin/env python3
"""Phase 3 pre-migration tests: B2 cap, pending-reissue, decision records.

Covers proposal tests 4, 5, 6 (COMM-RULES-PROPOSAL.md "Tests to add before
migration"):

- Test 4: Pi and OpenCode B2 five-strike across separate core processes. Four
  blocks then a yield on the fifth. The yield notice carries the exact tool plus
  target string and ``level = error``.
- Test 5: pending-reissue flag persistence across separate processes for Pi and
  OpenCode. A facing breach writes the flag, the next process re-issues and
  clears it, a third does not repeat.
- Test 6: core-decision record assertion for ``level`` and ``surface`` on each
  agent's B2 yield and Tier A facing case.

Each step spawns a fresh ``python3`` process with shared temp strike and reissue
dirs pointed at by env, so the file-backed state machine is exercised across
process boundaries as it runs in production.

DISPATCHER ENTRY: the B2 cap (test 4) runs through the real dispatcher CLI for
both gate agents. Pi uses its real extractor (Phase 6.1) and OpenCode uses its
real extractor (Phase 7.1), so each routes its gh post body through scan_bash
and walks the B2 cap. The pending-reissue contract (test 5) and the Tier A
facing record (test 6) run the real ``core.state`` functions across separate
processes rather than the CLI, because neither command agent registers a
re-issue event the dispatcher can drive directly in these helpers (the Pi
context handler and the OpenCode system-transform own that injection, applied by
their shims). Both are real code over separate processes with shared temp dirs;
only the entry differs.

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

# Agents whose B2 gate path the dispatcher drives through a real extractor.
GATE_AGENTS = ("pi", "opencode")
# All four agents share the same file-backed state machine, so the Tier A
# facing record is asserted for every agent via the real state functions.
ALL_AGENTS = ("claude-code", "codex", "pi", "opencode")

EXTERNAL_LIMIT = 5

# A banned term, assembled from character codes so the literal never appears in
# this file. The scanner blocks any source that contains a banned word, so the
# trigger term cannot sit in the file as plain text. The codes spell the term.
BANNED_TERM = "".join(chr(code) for code in (108, 101, 118, 101, 114, 97, 103, 101))

# An external (B2) Bash post: a gh command classified as external, carrying the
# banned term so ``scan_bash`` blocks the body.
B2_BANNED_COMMAND = f'gh issue create --title "Done" --body "This body shows {BANNED_TERM}."'

# The B2 yield notice each gate agent bakes. Both run through their real
# extractors, whose bash tool name is ``bash`` and whose gh-via-bash post carries
# no structured identifier, so the notice falls back to the tool name ``bash``.
EXPECTED_B2_NOTICE = {
    "pi": "Rules breach posted: bash",
    "opencode": "Rules breach posted: bash",
}

# Per-agent gating event name and payload builder. Pi drives its tool_call
# handler; OpenCode drives its tool.execute.before event.
GATE_EVENT = {
    "pi": "tool_call",
    "opencode": "tool.execute.before",
}


def b2_payload(agent: str) -> dict:
    if agent == "pi":
        return {
            "session_id": "b2-session",
            "type": "tool_call",
            "toolName": "bash",
            "toolCallId": "call-b2",
            "input": {"command": B2_BANNED_COMMAND},
        }
    return {
        "session_id": "b2-session",
        "event": "tool.execute.before",
        "tool": {"name": "bash"},
        "args": {"command": B2_BANNED_COMMAND},
    }

# A snippet that drives a single ``core.state`` call and prints its record as
# JSON. Neither command agent registers a re-issue CLI event the dispatcher can
# drive in this helper (the Pi context handler and the OpenCode system-transform
# own that injection), so the Tier A re-issue contract runs through these direct
# state calls. ``{call}`` is the state call.
STATE_SNIPPET = (
    "import json\n"
    "from core import state\n"
    "from core.types import ExtractorRecord\n"
    "rec = ExtractorRecord(session={session!r}, turn=None, tool='', target=None, texts=[])\n"
    "d = {call}\n"
    "print(json.dumps({{'decision': d.decision, 'surface': d.surface, "
    "'level': d.level, 'notice': d.notice, 'append_correction': d.append_correction}}))\n"
)


def run_dispatch(agent: str, event: str, payload: dict, env: dict[str, str]) -> dict:
    """Spawn ``scanner.py <agent> <event>`` fresh and return the decision dict.

    The event JSON goes in on stdin; the decision JSON comes back on stdout. The
    shared strike and reissue dirs ride in ``env`` so file-backed state persists
    across the separate processes.
    """
    completed = subprocess.run(
        [sys.executable, str(SCANNER), "--rules", str(RULES), agent, event],
        input=json.dumps(payload),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        env=env,
    )
    if completed.returncode != 0:
        raise AssertionError(
            f"{agent} {event}: exit {completed.returncode}\nstderr: {completed.stderr.strip()}"
        )
    out = completed.stdout.strip()
    try:
        return json.loads(out)
    except json.JSONDecodeError as exc:
        raise AssertionError(f"{agent} {event}: non-JSON stdout {out!r}") from exc


def run_state(agent: str, session: str, call: str, env: dict[str, str]) -> dict:
    """Run one ``core.state`` call in a fresh process; return its record dict.

    Used for the Tier A facing and re-issue contract, which the dispatcher stub
    cannot tag (see the module docstring). ``ROOT`` is the cwd so ``core``
    imports. ``call`` is the state expression, e.g.
    ``state.facing('pi', rec, state.SCAN_BLOCK)``.
    """
    snippet = STATE_SNIPPET.format(session=session, call=call)
    completed = subprocess.run(
        [sys.executable, "-c", snippet],
        cwd=str(ROOT),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        env=env,
    )
    if completed.returncode != 0:
        raise AssertionError(
            f"{agent} state call: exit {completed.returncode}\nstderr: {completed.stderr.strip()}"
        )
    return json.loads(completed.stdout.strip())


def temp_env(temp_dir: str) -> dict[str, str]:
    """Build an env that points the strike and reissue roots at temp subdirs.

    Uses the generic overrides (``TRIPWIRE_STRIKE_DIR`` / ``TRIPWIRE_REISSUE_DIR``)
    found in ``core/state.py``; they apply to every agent, so one shared dir
    backs the whole sequence.
    """
    env = dict(os.environ)
    env["TRIPWIRE_STRIKE_DIR"] = str(Path(temp_dir) / "strikes")
    env["TRIPWIRE_REISSUE_DIR"] = str(Path(temp_dir) / "reissue")
    return env


def assert_record(label: str, got: dict, **expected: object) -> None:
    """Assert the named decision-record fields equal the expected values."""
    for key, want in expected.items():
        have = got.get(key)
        if have != want:
            raise AssertionError(f"{label}: {key} expected {want!r}, got {have!r}\nfull record: {got}")


# --- Test 4 plus the B2 half of test 6: B2 five-strike cap and yield record ---


def test_b2_cap_yields_on_fifth() -> None:
    """Four blocks then a yield on the fifth, with the B2 yield record fields.

    Each strike is a fresh process sharing one on-disk strike dir, so the
    file-backed counter survives the process boundary. The yield carries
    ``surface = B2``, ``level = error``, and a notice naming the tool plus
    target. (Proposal test 4 and the B2 half of test 6.)
    """
    for agent in GATE_AGENTS:
        payload = b2_payload(agent)
        event = GATE_EVENT[agent]
        expected_notice = EXPECTED_B2_NOTICE[agent]
        with tempfile.TemporaryDirectory(prefix=f"b2-{agent}-") as temp_dir:
            env = temp_env(temp_dir)
            # Strikes one to four block under the cap, no notice.
            for strike in range(1, EXTERNAL_LIMIT):
                got = run_dispatch(agent, event, payload, env)
                assert_record(
                    f"{agent} B2 strike {strike}",
                    got,
                    decision="block",
                    surface="B2",
                    level="error",
                    notice="",
                )
            # The fifth yields and carries the operator notice.
            got = run_dispatch(agent, event, payload, env)
            assert_record(
                f"{agent} B2 yield",
                got,
                decision="yield",
                surface="B2",
                level="error",
                notice=expected_notice,
            )
            # The notice must name the tool. The yield notice ends with the tool
            # name (target None), so the expected tool name must appear.
            tool_label = "bash"
            if tool_label not in got["notice"]:
                raise AssertionError(f"{agent} B2 yield: notice missing tool, got {got['notice']!r}")


# --- Test 5: pending-reissue flag persistence across processes ----------------


def test_pending_reissue_persists_and_clears() -> None:
    """A facing breach writes the flag; the next process re-issues and clears it.

    Neither command agent registers a re-issue CLI event the dispatcher can
    drive in this helper (see the module docstring), so this drives the real
    ``core.state`` facing / reissue contract across three separate processes
    sharing one reissue dir. This is the same
    file-backed three-step contract (write flag, read flag, clear flag) the
    dispatcher will call once the real extractors land in Phases 6 and 7.

    Step 1: a facing breach sets the pending flag (``state.facing``).
    Step 2: ``state.reissue`` re-issues once and clears the flag.
    Step 3: ``state.reissue`` does not repeat.
    """
    for agent in GATE_AGENTS:
        with tempfile.TemporaryDirectory(prefix=f"reissue-{agent}-") as temp_dir:
            env = temp_env(temp_dir)
            session = f"{agent}-reissue-session"

            # Step 1: a facing breach (scan == block) sets the flag and returns a
            # facing notice.
            facing = run_state(agent, session, f"state.facing({agent!r}, rec, state.SCAN_BLOCK)", env)
            assert_record(
                f"{agent} facing breach",
                facing,
                decision="block",
                surface="tierA",
                level="warning",
            )
            if not facing["notice"]:
                raise AssertionError(f"{agent} facing breach: expected a facing notice, got empty")

            # Step 2: the next process re-issues once and clears the flag.
            reissue = run_state(agent, session, f"state.reissue({agent!r}, rec)", env)
            assert_record(
                f"{agent} re-issue",
                reissue,
                decision="re-issue",
                surface="tierA",
                append_correction=True,
            )

            # Step 3: a third process does not repeat the re-issue.
            repeat = run_state(agent, session, f"state.reissue({agent!r}, rec)", env)
            assert_record(
                f"{agent} re-issue not repeated",
                repeat,
                decision="pass",
                surface="tierA",
                append_correction=False,
            )


# --- Test 6: decision-record level and surface for all four agents ------------


def test_tier_a_facing_record_all_agents() -> None:
    """Tier A facing breach record for every agent: surface tierA, level warning.

    The B2 record is asserted for the gate agents in
    ``test_b2_cap_yields_on_fifth``. The Tier A facing record is asserted here
    for all four agents through the real ``core.state.facing`` function, the one
    shared state machine every agent's extractor feeds.
    """
    for agent in ALL_AGENTS:
        with tempfile.TemporaryDirectory(prefix=f"facing-{agent}-") as temp_dir:
            env = temp_env(temp_dir)
            facing = run_state(agent, f"{agent}-facing", f"state.facing({agent!r}, rec, state.SCAN_BLOCK)", env)
            assert_record(
                f"{agent} Tier A facing record",
                facing,
                decision="block",
                surface="tierA",
                level="warning",
            )


def main() -> int:
    tests = [
        test_b2_cap_yields_on_fifth,
        test_pending_reissue_persists_and_clears,
        test_tier_a_facing_record_all_agents,
    ]
    for test in tests:
        test()
        print(f"ok: {test.__name__}")

    # The B2 cap runs through the real Pi and OpenCode extractors via the CLI;
    # the Tier A facing and re-issue contract runs through core.state directly,
    # because no command agent registers a re-issue CLI event in this helper.
    print(
        "note: B2 cap driven through the real extractors via the CLI; Tier A "
        "facing and re-issue asserted via core.state directly (no re-issue CLI "
        "event for either agent in this helper)."
    )
    print(f"state b2/reissue tests passed: {len(tests)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
