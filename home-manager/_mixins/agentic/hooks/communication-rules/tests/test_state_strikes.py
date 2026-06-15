#!/usr/bin/env python3
"""File-backed strike sequence tests for Pi and OpenCode.

These cover proposal tests 1, 2, and 3 (COMM-RULES-PROPOSAL.md, "Tests to add
before migration"). They prove the file-backed strike move before the
in-process TS Map state is deleted:

1. Pi B1 strike sequence across separate core processes (block, block, yield),
   same session, tool, and path, sharing one on-disk strike dir.
2. OpenCode B1 strike sequence across separate core processes.
3. Pi and OpenCode B1 reset-on-clean-pass across processes (breach, clean pass,
   breach; the third is strike 1, so block not yield).

Each step spawns "scanner.py <agent> <event>" as a fresh subprocess with the
per-agent strike-dir env pointed at a per-test temp dir, and feeds the event
JSON on stdin. Both Pi (Phase 6) and OpenCode (Phase 7) have real extractors, so
each drives its own handler and event shape: Pi the tool_call handler (toolName
"bash", command under "input"), OpenCode the tool.execute.before event (tool
name "bash", command under "args"). Either way a Bash command body flows through
scan_bash -> state -> responder. We use a local tee redirect carrying a banned
word: it writes prose to disk (a B1 local surface), not a gh post, so it walks
the three-strike B1 cap, not the five-strike B2 cap.

The runner asserts the full decision record (decision, surface, notice, level),
not the verb alone. Stdlib only.
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

# Per-agent strike-dir env var the state machine honours (core/state.py
# _strike_dir). Pointing it at a temp dir shares one on-disk strike root across
# the separate core processes a sequence spawns.
STRIKE_DIR_ENV = {
    "pi": "TRIPWIRE_PI_STRIKE_DIR",
    "opencode": "TRIPWIRE_OPENCODE_STRIKE_DIR",
}

# A local B1 breach: a tee redirect writes a banned term to a file. The body is
# a local surface (not a gh post), so it walks the three-strike B1 cap. The
# banned terms are the breach payload, so they must appear here verbatim.
_BANNED = "del" + "ve"
_BANNED2 = "tap" + "estry"
BREACH_COMMAND = 'echo "%s into the %s" | tee notes.md' % (_BANNED, _BANNED2)

# A clean local command on the same shape: a tee redirect with no banned term.
# It clears the B1 strike for the same key.
CLEAN_COMMAND = "echo hello | tee notes.md"


# Per-agent gating event name and event shape. Both extractors are real: Pi
# drives its tool_call handler (toolName "bash", command under "input");
# OpenCode drives its tool.execute.before event (tool name "bash", command under
# "args").
GATING_EVENT = {
    "pi": "tool_call",
    "opencode": "tool.execute.before",
}


def event_json(agent, session, command):
    """Build the gating tool-call event the agent's extractor reads."""
    if agent == "pi":
        return json.dumps(
            {
                "session_id": session,
                "type": "tool_call",
                "toolName": "bash",
                "toolCallId": "call-strike",
                "input": {"command": command},
            }
        )
    return json.dumps(
        {
            "session_id": session,
            "event": "tool.execute.before",
            "tool": {"name": "bash"},
            "args": {"command": command},
        }
    )


def run_step(agent, strike_dir, session, command):
    """Spawn one fresh core process for a step and return its decision record.

    The strike-dir env points the shared on-disk strike root at strike_dir, so
    successive steps in a sequence share state across processes.
    """
    env = dict(os.environ)
    env[STRIKE_DIR_ENV[agent]] = strike_dir
    completed = subprocess.run(
        [sys.executable, str(SCANNER), "--rules", str(RULES), agent, GATING_EVENT[agent]],
        input=event_json(agent, session, command),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        env=env,
    )
    if completed.returncode != 0:
        raise AssertionError(
            "%s step exited %s: stdout=%r stderr=%r"
            % (agent, completed.returncode, completed.stdout, completed.stderr.strip())
        )
    output = completed.stdout.strip()
    try:
        return json.loads(output)
    except json.JSONDecodeError as error:
        raise AssertionError("%s step emitted non-JSON: %r" % (agent, output)) from error


def assert_decision(label, record, decision, surface):
    """Assert the full decision record for a step.

    At minimum the task requires decision and surface = B1. We assert the whole
    gating record so a verb-only false-green cannot slip through.
    """
    if record.get("decision") != decision:
        raise AssertionError("%s: expected decision %r, got %r (%s)" % (label, decision, record.get("decision"), record))
    if record.get("surface") != surface:
        raise AssertionError("%s: expected surface %r, got %r (%s)" % (label, surface, record.get("surface"), record))
    # A B1 block carries a warning level and no notice; the limit-th yield
    # carries the local-yield notice. Assert level and notice for completeness.
    if record.get("level") != "warning":
        raise AssertionError("%s: expected level 'warning', got %r (%s)" % (label, record.get("level"), record))
    if decision == "yield":
        if not record.get("notice"):
            raise AssertionError("%s: yield must carry a notice, got %r" % (label, record.get("notice")))
    else:
        if record.get("notice"):
            raise AssertionError("%s: %s must carry no notice, got %r" % (label, decision, record.get("notice")))


def test_b1_strike_sequence(agent):
    """Block, block, yield across three separate processes, one shared dir."""
    with tempfile.TemporaryDirectory(prefix="tripwire-%s-b1-" % agent) as strike_dir:
        session = "%s-b1-seq" % agent
        first = run_step(agent, strike_dir, session, BREACH_COMMAND)
        assert_decision("%s B1 strike 1" % agent, first, "block", "B1")
        second = run_step(agent, strike_dir, session, BREACH_COMMAND)
        assert_decision("%s B1 strike 2" % agent, second, "block", "B1")
        third = run_step(agent, strike_dir, session, BREACH_COMMAND)
        assert_decision("%s B1 strike 3" % agent, third, "yield", "B1")
    return 1


def test_b1_reset_on_clean_pass(agent):
    """Breach, clean pass, breach; the clean pass resets, so the third blocks."""
    with tempfile.TemporaryDirectory(prefix="tripwire-%s-reset-" % agent) as strike_dir:
        session = "%s-b1-reset" % agent
        first = run_step(agent, strike_dir, session, BREACH_COMMAND)
        assert_decision("%s reset breach 1" % agent, first, "block", "B1")
        clean = run_step(agent, strike_dir, session, CLEAN_COMMAND)
        assert_decision("%s reset clean pass" % agent, clean, "pass", "B1")
        # The clean pass cleared the strike, so this breach is strike 1: block,
        # not yield. A leaked count would yield here.
        third = run_step(agent, strike_dir, session, BREACH_COMMAND)
        assert_decision("%s reset breach 2 (strike 1)" % agent, third, "block", "B1")
    return 1


def main():
    if not RULES.is_file():
        print("missing rules file: %s" % RULES, file=sys.stderr)
        return 2

    total = 0
    for agent in ("pi", "opencode"):
        total += test_b1_strike_sequence(agent)
        total += test_b1_reset_on_clean_pass(agent)

    print("state strike tests passed: %s" % total)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
