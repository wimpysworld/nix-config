#!/usr/bin/env python3
"""File-backed B1 strike tests for the block-then-allow-revise hybrid.

Tier B1 (local writes, edits, patches, Bash command bodies) no longer blocks
three times then yields. It now blocks once, cheaply, then allows the write and
asks for an in-place revision of the named target on every later breach. A clean
scan resets the per-target strike count, so a target that goes clean then
breaches again earns a fresh block. B1 never reaches the old terminal ``yield``
(that verb stays B2-only). These tests pin that hybrid down:

1. B1 strike sequence: strike 1 -> ``block`` (empty notice, level ``warning``);
   strike 2 and every later strike -> ``allow-revise`` (surface ``B1``, a
   non-empty notice, no terminal yield). Driven across separate core processes
   for Pi and OpenCode over one shared on-disk strike dir, the raw decision
   record asserted. The resolved user-facing notice is asserted through the
   command-agent CLI, which runs the dispatcher's ``shape_response``: a file
   tool (Write) names its concrete path; a Bash write now keys on its prose sink
   so it also names that file; a genuinely empty target (driven directly through
   the dispatcher) degrades to the generic form and never emits a ``{target}``.
   A separate per-file keying check proves two distinct Bash sinks each earn
   their own one-block budget instead of sharing one coarse session+tool key.
2. Reset on clean pass: breach -> ``block``, clean pass -> ``pass`` (resets the
   count), breach -> ``block`` again (strike 1, a fresh block, not allow-revise).
3. ``TRIPWIRE_LOCAL_STRIKE_LIMIT`` override: set to ``2``, strikes 1-2 block and
   strike 3 allow-revises. Unset, the effective limit equals the single-sourced
   ``LOCAL_STRIKE_LIMIT`` constant.
4. Per-turn dedupe: a duplicate breach in the same turn (``existing_blocked``)
   takes no second strike and no second notice, driven through ``core.state.gate``
   directly (mirroring ``test_state_b2_reissue.py``).

Why two entry points. The strike sequence and reset drive the Pi / OpenCode CLI
and read the raw decision record (verb, surface, level, notice emptiness). The
RESOLVED ``allow-revise`` notice is produced by the dispatcher's
``shape_response``, not by ``gate`` (``gate`` puts the raw target in ``notice``).
The CLI runs ``shape_response`` only for the command agents (Claude Code,
Codex), whose stdout is the agent's native wire dict. So the resolved-notice
assertions drive the Claude Code CLI and read
``hookSpecificOutput.permissionDecisionReason``. The dedupe assertion is a
raw-gate property, so it calls ``core.state.gate`` directly.

The banned breach terms never sit in this file as literals; they are assembled
from fragments, as the sibling tests do. Stdlib only. British English in
comments.
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
    "claude-code": "TRIPWIRE_CLAUDE_CODE_STRIKE_DIR",
}

# A local B1 breach: a tee redirect writes a banned term to a file. The body is
# a local surface (not a gh post), so it walks the B1 cap. The banned terms are
# the breach payload, so they are assembled from fragments here, never written
# as plain literals.
_BANNED = "del" + "ve"
_BANNED2 = "tap" + "estry"
BREACH_COMMAND = 'echo "%s into the %s" | tee notes.md' % (_BANNED, _BANNED2)

# Two breaching Bash writes to two DIFFERENT prose sinks. Each sink is now the
# B1 strike target (bash_prose_sink), so in one session each earns its own
# one-block budget instead of sharing one coarse session+tool key. The banned
# term is the breach payload, assembled from fragments, never a plain literal.
BREACH_COMMAND_A = 'printf "%s here" > /tmp/tripwire-a.md' % _BANNED
BREACH_COMMAND_B = 'printf "%s here" > /tmp/tripwire-b.md' % _BANNED

# A clean local command on the same shape: a tee redirect with no banned term.
# It clears the B1 strike for the same key.
CLEAN_COMMAND = "echo hello | tee notes.md"

# The Bash sink the BREACH_COMMAND writes (tee notes.md). It is a prose suffix,
# so the resolved allow-revise notice now NAMES this file.
BREACH_COMMAND_SINK = "notes.md"

# A file-tool breach for the resolved-notice case: a Write whose content carries
# a banned term, against a concrete path. The path is the strike target, so the
# resolved allow-revise notice must name it (acceptance criterion 2).
BREACH_FILE_PATH = "/tmp/tripwire-b1-notes.md"
BREACH_FILE_CONTENT = "We %s into the work here." % _BANNED


# Per-agent gating event name and event shape. Both plugin extractors are real:
# Pi drives its tool_call handler (toolName "bash", command under "input");
# OpenCode drives its tool.execute.before event (tool name "bash", command under
# "args"). Claude Code drives PreToolUse (tool_name / tool_input).
GATING_EVENT = {
    "pi": "tool_call",
    "opencode": "tool.execute.before",
    "claude-code": "PreToolUse",
}


def bash_event_json(agent, session, command):
    """Build the gating Bash tool-call event the agent's extractor reads."""
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
    if agent == "opencode":
        return json.dumps(
            {
                "session_id": session,
                "event": "tool.execute.before",
                "tool": {"name": "bash"},
                "args": {"command": command},
            }
        )
    # Claude Code PreToolUse Bash call.
    return json.dumps(
        {
            "session_id": session,
            "tool_name": "Bash",
            "tool_input": {"command": command},
        }
    )


def claude_write_event_json(session, file_path, content):
    """Build a Claude Code PreToolUse Write event against a concrete path."""
    return json.dumps(
        {
            "session_id": session,
            "tool_name": "Write",
            "tool_input": {"file_path": file_path, "content": content},
        }
    )


def run_step(agent, strike_dir, payload, env_extra=None):
    """Spawn one fresh core process for a step and return its raw stdout text.

    The strike-dir env points the shared on-disk strike root at strike_dir, so
    successive steps in a sequence share state across processes. ``env_extra``
    layers extra env (the limit override) on top.
    """
    env = dict(os.environ)
    env[STRIKE_DIR_ENV[agent]] = strike_dir
    if env_extra:
        env.update(env_extra)
    completed = subprocess.run(
        [sys.executable, str(SCANNER), "--rules", str(RULES), agent, GATING_EVENT[agent]],
        input=payload,
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
    return completed.stdout.strip()


def run_record(agent, strike_dir, session, command, env_extra=None):
    """Run one Bash step for a plugin agent and return its raw decision record."""
    output = run_step(agent, strike_dir, bash_event_json(agent, session, command), env_extra)
    try:
        return json.loads(output)
    except json.JSONDecodeError as error:
        raise AssertionError("%s step emitted non-JSON: %r" % (agent, output)) from error


def claude_reason(strike_dir, payload):
    """Run one Claude Code step and return its shaped wire dict.

    Claude Code stdout is the agent's native wire JSON (the dispatcher ran
    ``shape_response``), so this is where the resolved allow-revise notice
    appears, under ``hookSpecificOutput.permissionDecisionReason``. A silent
    outcome (a pass) emits nothing, returned here as ``None``.
    """
    output = run_step("claude-code", strike_dir, payload)
    if not output:
        return None
    try:
        return json.loads(output)
    except json.JSONDecodeError as error:
        raise AssertionError("claude-code step emitted non-JSON: %r" % output) from error


def assert_decision(label, record, decision, surface):
    """Assert the raw decision record for a B1 step.

    ``block`` carries an empty notice and level ``warning``; ``pass`` carries an
    empty notice; ``allow-revise`` carries a NON-empty notice (the raw target the
    gate placed there, resolved downstream) and stays level ``warning``. B1
    never reaches the terminal ``yield``. No notice on any surface may contain a
    literal ``{target}`` placeholder.
    """
    if record.get("decision") != decision:
        raise AssertionError("%s: expected decision %r, got %r (%s)" % (label, decision, record.get("decision"), record))
    if record.get("surface") != surface:
        raise AssertionError("%s: expected surface %r, got %r (%s)" % (label, surface, record.get("surface"), record))
    # B1 stays at level warning for every verb; it never reaches the B2 error
    # yield. Assert it for completeness so a level regression cannot slip past.
    if record.get("level") != "warning":
        raise AssertionError("%s: expected level 'warning', got %r (%s)" % (label, record.get("level"), record))
    notice = record.get("notice")
    if decision == "allow-revise":
        # Strike 2+ allows the write and carries a notice. On a plugin agent the
        # raw record carries the gate-supplied target (here empty for Bash, see
        # the resolved-notice cases for the user-facing text); on a file tool it
        # carries the path. Either way no literal placeholder may survive.
        if "{target}" in (notice or ""):
            raise AssertionError("%s: notice must not contain a literal {target}, got %r" % (label, notice))
    else:
        if notice:
            raise AssertionError("%s: %s must carry no notice, got %r" % (label, decision, notice))


def assert_no_target_placeholder(label, text):
    """The resolved notice must never leak a literal ``{target}`` placeholder."""
    if "{target}" in text:
        raise AssertionError("%s: resolved notice leaked a literal {target}: %r" % (label, text))


def test_b1_strike_sequence(agent):
    """Strike 1 blocks; strike 2 and strike 3 allow-revise (no terminal yield).

    Three separate processes share one on-disk strike dir, so the file-backed
    counter survives the process boundary. Driven through the plugin agent's
    real Bash extractor; the raw decision record is asserted.
    """
    with tempfile.TemporaryDirectory(prefix="tripwire-%s-b1-" % agent) as strike_dir:
        session = "%s-b1-seq" % agent
        first = run_record(agent, strike_dir, session, BREACH_COMMAND)
        assert_decision("%s B1 strike 1" % agent, first, "block", "B1")
        second = run_record(agent, strike_dir, session, BREACH_COMMAND)
        assert_decision("%s B1 strike 2" % agent, second, "allow-revise", "B1")
        third = run_record(agent, strike_dir, session, BREACH_COMMAND)
        assert_decision("%s B1 strike 3" % agent, third, "allow-revise", "B1")
    return 1


def test_b1_reset_on_clean_pass(agent):
    """Breach -> block, clean pass -> pass (resets), breach -> block (strike 1)."""
    with tempfile.TemporaryDirectory(prefix="tripwire-%s-reset-" % agent) as strike_dir:
        session = "%s-b1-reset" % agent
        first = run_record(agent, strike_dir, session, BREACH_COMMAND)
        assert_decision("%s reset breach 1" % agent, first, "block", "B1")
        clean = run_record(agent, strike_dir, session, CLEAN_COMMAND)
        assert_decision("%s reset clean pass" % agent, clean, "pass", "B1")
        # The clean pass cleared the count, so this breach is strike 1 again: a
        # fresh block, not allow-revise. A leaked count would allow-revise here.
        third = run_record(agent, strike_dir, session, BREACH_COMMAND)
        assert_decision("%s reset breach 2 (strike 1)" % agent, third, "block", "B1")
    return 1


def test_b1_resolved_notice_file_tool():
    """A file-tool allow-revise names the concrete path in the resolved notice.

    Driven through the Claude Code CLI so the dispatcher's ``shape_response``
    resolves the B1 revision prompt and substitutes the path. Strike 1 denies
    (the rules block message); strike 2 allows the write, with a
    ``permissionDecisionReason`` that names the file and carries no literal
    ``{target}`` (acceptance criterion 2 and 11).
    """
    with tempfile.TemporaryDirectory(prefix="tripwire-cc-file-") as strike_dir:
        payload = claude_write_event_json("cc-b1-file", BREACH_FILE_PATH, BREACH_FILE_CONTENT)

        first = claude_reason(strike_dir, payload)
        if first is None:
            raise AssertionError("file-tool strike 1: expected a deny payload, got nothing")
        decision = first["hookSpecificOutput"]["permissionDecision"]
        if decision != "deny":
            raise AssertionError("file-tool strike 1: expected deny, got %r (%s)" % (decision, first))

        second = claude_reason(strike_dir, payload)
        if second is None:
            raise AssertionError("file-tool strike 2: expected an allow payload, got nothing")
        out = second["hookSpecificOutput"]
        if out["permissionDecision"] != "allow":
            raise AssertionError("file-tool strike 2: expected allow, got %r (%s)" % (out["permissionDecision"], second))
        reason = out["permissionDecisionReason"]
        if BREACH_FILE_PATH not in reason:
            raise AssertionError("file-tool strike 2: resolved notice missing path %r, got %r" % (BREACH_FILE_PATH, reason))
        assert_no_target_placeholder("file-tool strike 2", reason)
    return 1


def test_b1_resolved_notice_bash_named():
    """A Bash write to a prose file NAMES that file in the resolved notice.

    A Bash write now keys on its prose sink (``bash_prose_sink``), so the strike
    target is the sink path and the dispatcher substitutes it into the B1
    revision prompt, exactly like a Write/Edit tool. Driven through the Claude
    Code CLI: strike 1 denies, strike 2 allows with a ``permissionDecisionReason``
    that names the sink (here ``notes.md``) and carries no literal ``{target}``.
    """
    with tempfile.TemporaryDirectory(prefix="tripwire-cc-bash-") as strike_dir:
        payload = bash_event_json("claude-code", "cc-b1-bash", BREACH_COMMAND)

        first = claude_reason(strike_dir, payload)
        if first is None:
            raise AssertionError("Bash strike 1: expected a deny payload, got nothing")
        if first["hookSpecificOutput"]["permissionDecision"] != "deny":
            raise AssertionError("Bash strike 1: expected deny, got %s" % first)

        second = claude_reason(strike_dir, payload)
        if second is None:
            raise AssertionError("Bash strike 2: expected an allow payload, got nothing")
        out = second["hookSpecificOutput"]
        if out["permissionDecision"] != "allow":
            raise AssertionError("Bash strike 2: expected allow, got %r (%s)" % (out["permissionDecision"], second))
        reason = out["permissionDecisionReason"]
        if BREACH_COMMAND_SINK not in reason:
            raise AssertionError("Bash strike 2: resolved notice missing sink %r, got %r" % (BREACH_COMMAND_SINK, reason))
        assert_no_target_placeholder("Bash strike 2", reason)
    return 1


def test_b1_resolved_notice_empty_target_generic():
    """A genuinely empty B1 target degrades to the generic notice, no {target}.

    A Bash write usually now resolves a sink, so the empty-target path can no
    longer be reached through a real breaching command. Drive the empty-target
    case directly through ``gate`` plus the dispatcher's ``shape_response``: a B1
    allow-revise whose ``record.target`` is empty must produce the baked generic
    sentence, name no file, and never emit a literal ``{target}`` (criterion 11).
    """
    snippet = (
        "from core import state, dispatch\n"
        "from core.config import Config, DEFAULT_POLICY\n"
        "from core.types import ExtractorRecord\n"
        "config = Config(rules_text='rules', reminder_prompt=None, block_message=None, policy=dict(DEFAULT_POLICY))\n"
        "rec = ExtractorRecord(session='empty-target', turn=None, tool='Bash', target=None, texts=[])\n"
        "state.gate('claude-code', rec, 'local', state.SCAN_BLOCK)\n"
        "decision = state.gate('claude-code', rec, 'local', state.SCAN_BLOCK)\n"
        "wire = dispatch.shape_response('claude-code', 'PreToolUse', decision, config)\n"
        "reason = wire['hookSpecificOutput']['permissionDecisionReason']\n"
        "print(repr(reason))\n"
        "print(repr(dispatch._GENERIC_REVISION_NOTICE))\n"
    )
    with tempfile.TemporaryDirectory(prefix="tripwire-empty-target-") as strike_dir:
        env = dict(os.environ)
        env["TRIPWIRE_STRIKE_DIR"] = strike_dir
        env.pop("TRIPWIRE_B1_REVISION_PROMPT", None)
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
        raise AssertionError("empty-target check exited %s: %s" % (completed.returncode, completed.stderr.strip()))
    reason_line, generic_line = completed.stdout.strip().splitlines()
    reason = eval(reason_line)  # noqa: S307 - test-only, value is our own repr
    generic = eval(generic_line)  # noqa: S307 - test-only, value is our own repr
    if reason != generic:
        raise AssertionError("empty target: expected the generic notice %r, got %r" % (generic, reason))
    assert_no_target_placeholder("empty target", reason)
    return 1


def test_b1_bash_per_file_keying():
    """Two breaching Bash writes to two different prose sinks each block once.

    Before this change a single coarse session+tool key meant the first
    breaching Bash write blocked and every later breaching Bash write (any file)
    landed. Now each Bash write keys on its prose sink, so two distinct sinks in
    one session each get their OWN one-block budget: both are strike 1 and both
    deny. Driven through the plugin agents over one shared strike dir.
    """
    for agent in ("pi", "opencode"):
        with tempfile.TemporaryDirectory(prefix="tripwire-%s-perfile-" % agent) as strike_dir:
            session = "%s-b1-perfile" % agent
            first_a = run_record(agent, strike_dir, session, BREACH_COMMAND_A)
            assert_decision("%s per-file sink A strike 1" % agent, first_a, "block", "B1")
            # A DIFFERENT sink in the same session is its own strike 1, not a free
            # pass. A coarse shared key would allow-revise here instead.
            first_b = run_record(agent, strike_dir, session, BREACH_COMMAND_B)
            assert_decision("%s per-file sink B strike 1" % agent, first_b, "block", "B1")
            # A SECOND breach to sink A names that file on allow-revise.
            second_a = run_record(agent, strike_dir, session, BREACH_COMMAND_A)
            assert_decision("%s per-file sink A strike 2" % agent, second_a, "allow-revise", "B1")
            if second_a.get("notice") != "/tmp/tripwire-a.md":
                raise AssertionError(
                    "%s per-file sink A strike 2: expected notice '/tmp/tripwire-a.md', got %r"
                    % (agent, second_a.get("notice"))
                )
    return 1


def test_bash_prose_sink_unit():
    """``bash_prose_sink`` returns the first prose sink, else None.

    Covers a cat heredoc, tee, echo/printf redirect, append ``>>``, a dynamic
    sink (``$(...)`` -> None), and a non-prose target (-> None). The banned term
    is irrelevant here; this checks the SINK resolver, not detection. Run in a
    fresh process so the import path matches the other checks.
    """
    snippet = (
        "from core.detection import bash_prose_sink as s\n"
        "cases = [\n"
        "  (s('cat > out.md <<EOF\\nhi\\nEOF'), 'out.md'),\n"
        "  (s('echo hi | tee notes.md'), 'notes.md'),\n"
        "  (s('echo hi > comment.txt'), 'comment.txt'),\n"
        "  (s('printf x >> log.md'), 'log.md'),\n"
        "  (s('echo hi > $(mktemp).md'), None),\n"
        "  (s('echo hi > out.bin'), None),\n"
        "  (s('ls -la'), None),\n"
        # A shell -c wrapper hides its sink in one token; unwrapping resolves it.
        "  (s('bash -lc \"printf \\'x\\' > out.md\"'), 'out.md'),\n"
        "  (s('sh -c \"echo hi > notes.txt\"'), 'notes.txt'),\n"
        # A clean wrapped command with no prose sink resolves to None.
        "  (s('bash -lc \"ls -la\"'), None),\n"
        # A doubly nested wrapper within the depth cap still resolves the sink.
        "  (s('bash -lc \"sh -c \\'echo hi > deep.md\\'\"'), 'deep.md'),\n"
        "]\n"
        "import json\n"
        "print(json.dumps(cases))\n"
    )
    completed = subprocess.run(
        [sys.executable, "-c", snippet],
        cwd=str(ROOT),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if completed.returncode != 0:
        raise AssertionError("bash_prose_sink check exited %s: %s" % (completed.returncode, completed.stderr.strip()))
    results = json.loads(completed.stdout.strip())
    for got, want in results:
        if got != want:
            raise AssertionError("bash_prose_sink: expected %r, got %r (all=%r)" % (want, got, results))
    return 1


def test_scan_bash_wrapped_unit():
    """``scan_bash`` sees a banned word hidden inside a shell ``-c`` wrapper.

    A direct write blocks today; a ``bash -lc "..."`` wrapper used to hide its
    payload in one token and slip past. This proves the unwrap: the direct and
    the wrapped form both block, and a clean wrapped command passes. The banned
    word is assembled from fragments, never a plain literal. Run in a fresh
    process so the import path matches the other checks.
    """
    snippet = (
        "from core.detection import scan_bash\n"
        "from core.config import Config, DEFAULT_POLICY\n"
        "c = Config(rules_text='x', reminder_prompt=None, block_message=None, policy=dict(DEFAULT_POLICY))\n"
        "B = 'del' + 've'\n"
        "cases = [\n"
        "  (scan_bash(\"printf '%s' > x.md\" % B, c), True),\n"
        "  (scan_bash('bash -lc \"printf \\'%s\\' > x.md\"' % B, c), True),\n"
        "  (scan_bash('bash -lc \"ls -la\"', c), False),\n"
        "]\n"
        "import json\n"
        "print(json.dumps(cases))\n"
    )
    completed = subprocess.run(
        [sys.executable, "-c", snippet],
        cwd=str(ROOT),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if completed.returncode != 0:
        raise AssertionError("scan_bash wrapped check exited %s: %s" % (completed.returncode, completed.stderr.strip()))
    results = json.loads(completed.stdout.strip())
    for got, want in results:
        if got != want:
            raise AssertionError("scan_bash wrapped: expected %r, got %r (all=%r)" % (want, got, results))
    return 1


def test_apply_patch_target_unit():
    """``apply_patch_target`` returns the first Add/Update path, else None.

    Covers an Add File patch, an Update File patch (nested path), a delete-only
    patch (no write target -> None), and a pathless body (-> None). This is the
    Codex per-file keying resolver: a breaching apply_patch keys its B1 strike on
    this path, so two patches to two files each earn their own one-block budget
    instead of sharing one coarse session+turn+tool key. Run in a fresh process
    so the import path matches the other checks.
    """
    snippet = (
        "from core.detection import apply_patch_target as t\n"
        "cases = [\n"
        "  (t('*** Begin Patch\\n*** Add File: note.txt\\n+hi\\n*** End Patch\\n'), 'note.txt'),\n"
        "  (t('*** Begin Patch\\n*** Update File: src/app.md\\n+hi\\n*** End Patch\\n'), 'src/app.md'),\n"
        "  (t('*** Begin Patch\\n*** Delete File: gone.txt\\n*** End Patch\\n'), None),\n"
        "  (t('no markers here'), None),\n"
        "]\n"
        "import json\n"
        "print(json.dumps(cases))\n"
    )
    completed = subprocess.run(
        [sys.executable, "-c", snippet],
        cwd=str(ROOT),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if completed.returncode != 0:
        raise AssertionError("apply_patch_target check exited %s: %s" % (completed.returncode, completed.stderr.strip()))
    results = json.loads(completed.stdout.strip())
    for got, want in results:
        if got != want:
            raise AssertionError("apply_patch_target: expected %r, got %r (all=%r)" % (want, got, results))
    return 1


def test_strip_env_assignments_unit():
    """``strip_env_assignments`` drops leading env assignments only.

    Covers a single leading assignment, multiple leading assignments, an
    assignment AFTER the command (which stays, as a real argument), and an
    all-assignments argv (which returns empty). Run in a fresh process so the
    import path matches the other checks.
    """
    snippet = (
        "from core.detection import strip_env_assignments as s\n"
        "cases = [\n"
        "  (s(['GH_TOKEN=x', 'gh', 'issue']), ['gh', 'issue']),\n"
        "  (s(['A=1', 'B=2', 'printf', 'hi']), ['printf', 'hi']),\n"
        "  (s(['gh', 'api', '-f', 'k=v']), ['gh', 'api', '-f', 'k=v']),\n"
        "  (s(['FOO=bar']), []),\n"
        "  (s([]), []),\n"
        "]\n"
        "import json\n"
        "print(json.dumps(cases))\n"
    )
    completed = subprocess.run(
        [sys.executable, "-c", snippet],
        cwd=str(ROOT),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if completed.returncode != 0:
        raise AssertionError("strip_env_assignments check exited %s: %s" % (completed.returncode, completed.stderr.strip()))
    results = json.loads(completed.stdout.strip())
    for got, want in results:
        if got != want:
            raise AssertionError("strip_env_assignments: expected %r, got %r (all=%r)" % (want, got, results))
    return 1


def test_patch_added_text_unit():
    """``patch_added_text`` returns the ``+`` lines only, markers skipped.

    Covers added lines (the ``+`` stripped), the ``*** ...`` markers and the
    ``+++`` headers skipped, and a delete-only patch (no added lines -> empty).
    Run in a fresh process so the import path matches the other checks.
    """
    snippet = (
        "from core.detection import patch_added_text as p\n"
        "add = '*** Begin Patch\\n*** Add File: a.md\\n+hello\\n+world\\n*** End Patch\\n'\n"
        "hdr = '+++ b/a.md\\n+kept line\\n'\n"
        "dele = '*** Begin Patch\\n*** Delete File: gone.md\\n-bye\\n*** End Patch\\n'\n"
        "cases = [\n"
        "  (p(add), 'hello\\nworld'),\n"
        "  (p(hdr), 'kept line'),\n"
        "  (p(dele), ''),\n"
        "]\n"
        "import json\n"
        "print(json.dumps(cases))\n"
    )
    completed = subprocess.run(
        [sys.executable, "-c", snippet],
        cwd=str(ROOT),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if completed.returncode != 0:
        raise AssertionError("patch_added_text check exited %s: %s" % (completed.returncode, completed.stderr.strip()))
    results = json.loads(completed.stdout.strip())
    for got, want in results:
        if got != want:
            raise AssertionError("patch_added_text: expected %r, got %r (all=%r)" % (want, got, results))
    return 1


def test_b1_limit_override():
    """``TRIPWIRE_LOCAL_STRIKE_LIMIT=2`` blocks strikes 1-2 and allow-revises 3.

    The env override lets a live A/B flip the B1 budget without editing source.
    Driven through the Pi CLI with the override layered into the step env; the
    raw record is asserted across three shared-dir processes.
    """
    agent = "pi"
    override = {"TRIPWIRE_LOCAL_STRIKE_LIMIT": "2"}
    with tempfile.TemporaryDirectory(prefix="tripwire-limit-") as strike_dir:
        session = "limit-override-seq"
        first = run_record(agent, strike_dir, session, BREACH_COMMAND, override)
        assert_decision("override strike 1", first, "block", "B1")
        second = run_record(agent, strike_dir, session, BREACH_COMMAND, override)
        assert_decision("override strike 2", second, "block", "B1")
        third = run_record(agent, strike_dir, session, BREACH_COMMAND, override)
        assert_decision("override strike 3", third, "allow-revise", "B1")
    return 1


def test_b1_limit_default_equals_constant():
    """Unset, the effective B1 limit equals the single-sourced constant.

    Reads ``state._local_strike_limit()`` in a fresh process with the override
    explicitly cleared, and asserts it equals ``state.LOCAL_STRIKE_LIMIT`` (1).
    This proves the default is the constant, not a separate hardcoded copy
    (acceptance criterion 9, the default half).
    """
    env = dict(os.environ)
    env.pop("TRIPWIRE_LOCAL_STRIKE_LIMIT", None)
    snippet = (
        "from core import state\n"
        "print(state._local_strike_limit() == state.LOCAL_STRIKE_LIMIT "
        "and state.LOCAL_STRIKE_LIMIT == 1)\n"
    )
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
        raise AssertionError("default-limit check exited %s: %s" % (completed.returncode, completed.stderr.strip()))
    if completed.stdout.strip() != "True":
        raise AssertionError("default B1 limit must equal LOCAL_STRIKE_LIMIT (1), got %r" % completed.stdout.strip())
    return 1


def test_b1_per_turn_dedupe():
    """A duplicate breach in the same turn takes no second strike, no notice.

    Drives ``core.state.gate`` directly (mirroring ``test_state_b2_reissue.py``):
    a real first breach blocks (strike 1); a duplicate breach in the same turn
    (``existing_blocked=True``) returns block with an empty notice and takes no
    strike; the next real breach is therefore strike 2 (allow-revise), proving
    the dedupe consumed no budget (acceptance criterion 13).
    """
    snippet = (
        "import json\n"
        "from core import state\n"
        "from core.types import ExtractorRecord\n"
        "rec = ExtractorRecord(session='dedupe-turn', turn=None, tool='Write', "
        "target='/tmp/dedupe.md', texts=[])\n"
        "first = state.gate('claude-code', rec, 'local', state.SCAN_BLOCK)\n"
        "dup = state.gate('claude-code', rec, 'local', state.SCAN_BLOCK, existing_blocked=True)\n"
        "after = state.gate('claude-code', rec, 'local', state.SCAN_BLOCK)\n"
        "print(json.dumps([\n"
        "  [first.decision, first.notice],\n"
        "  [dup.decision, dup.notice],\n"
        "  [after.decision, after.notice],\n"
        "]))\n"
    )
    with tempfile.TemporaryDirectory(prefix="tripwire-dedupe-") as strike_dir:
        env = dict(os.environ)
        env["TRIPWIRE_STRIKE_DIR"] = strike_dir
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
            raise AssertionError("dedupe check exited %s: %s" % (completed.returncode, completed.stderr.strip()))
        first, dup, after = json.loads(completed.stdout.strip())

    if first != ["block", ""]:
        raise AssertionError("dedupe strike 1: expected block with empty notice, got %r" % (first,))
    # The duplicate in the same turn stays a silent block: no second notice.
    if dup != ["block", ""]:
        raise AssertionError("dedupe duplicate: expected silent block with empty notice, got %r" % (dup,))
    # The duplicate took no strike, so the next real breach is strike 2:
    # allow-revise carrying the raw target. A consumed dedupe strike would push
    # this past the limit too early or leave it at block.
    if after[0] != "allow-revise":
        raise AssertionError("dedupe next breach: expected allow-revise (strike 2), got %r" % (after,))
    return 1


def main():
    if not RULES.is_file():
        print("missing rules file: %s" % RULES, file=sys.stderr)
        return 2

    total = 0
    # The block-then-allow-revise sequence and the clean-scan reset over the two
    # plugin agents, raw decision record asserted.
    for agent in ("pi", "opencode"):
        total += test_b1_strike_sequence(agent)
        total += test_b1_reset_on_clean_pass(agent)

    # Per-file Bash keying: two distinct Bash sinks each get a one-block budget.
    total += test_b1_bash_per_file_keying()
    # The sink resolver unit check, the wrapped scan_bash detection check, and
    # the apply_patch path resolver check.
    total += test_bash_prose_sink_unit()
    total += test_scan_bash_wrapped_unit()
    total += test_apply_patch_target_unit()
    # The env-assignment strip and the patch added-text helpers.
    total += test_strip_env_assignments_unit()
    total += test_patch_added_text_unit()

    # The resolved user-facing notice via the command-agent CLI: a file tool and
    # a Bash write both name their concrete target; a genuinely empty target
    # degrades to the generic form, driven directly through the dispatcher.
    total += test_b1_resolved_notice_file_tool()
    total += test_b1_resolved_notice_bash_named()
    total += test_b1_resolved_notice_empty_target_generic()

    # The limit override and its default, and the per-turn dedupe.
    total += test_b1_limit_override()
    total += test_b1_limit_default_equals_constant()
    total += test_b1_per_turn_dedupe()

    print("state strike tests passed: %s" % total)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
