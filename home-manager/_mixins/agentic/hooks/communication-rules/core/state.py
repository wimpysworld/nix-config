"""The single file-backed strike, tier, and fail-closed machine.

This module collapses the four hand-written copies of one policy (two Bash
wrappers, two TypeScript plugins) into one place. It owns:

- Sub-tier B1 (local: write, edit, bash). Block-then-allow-revise: one cheap
  block, then allow the write and ask for an in-place revision of the target.
- Sub-tier B2 (external: post-capable tools, gh/gh-api-safe posts). Five-
  strike-then-yield, with the ``external:`` key namespace so a B2 key never
  aliases a B1 key for the same session and tool.
- The existing-blocked per-turn dedupe: a duplicate breach in the same turn
  takes no second notice and no second strike.
- A non-empty session guarantee before file-backing strikes, so strikes never
  leak across sessions when the session id is empty.
- Fail-closed on a gating surface: when the scanner cannot decide, deny or
  yield under the strike cap, never pass.
- Tier A re-issue-once: a facing breach writes a pending-reissue flag; a later
  call reads and clears it.
- Rules-injection dedupe, file-backed, keyed per session.

The two strike limits live here and nowhere else (acceptance criterion 4).
Detection and response shaping stay out of this module: they live in
``core.detection`` and ``core.responses``. This module owns state, the surface
limit and namespace, dedupe, fail-closed, and the decision verb plus surface,
level, and Tier A flags.
"""

from __future__ import annotations

import hashlib
import os
import re
from pathlib import Path

from core.types import Decision, ExtractorRecord


# Sub-tier B1 (local: write, edit, bash). Cheap to retract because the output
# lands on disk, not committed. Block-then-allow-revise, keyed on a stable
# target: strike 1 blocks (one cheap attempt before the write lands), every
# later strike allows the write and asks for an in-place revision of the named
# target. Only a clean scan resets the count, so each later breach re-emits.
LOCAL_STRIKE_LIMIT = 1

# Sub-tier B2 (external: post-capable tools, gh/gh-api-safe posts). Irretractable
# the instant it yields. Five-strike-then-yield, keyed on a stable identity so
# reworded retries of the same logical post draw down one budget.
EXTERNAL_STRIKE_LIMIT = 5

# The B2 key namespace prefix. Joined as the first key component so a B2 key for
# a session and tool never aliases the B1 key for the same session and tool.
EXTERNAL_NAMESPACE = "external"

# Stable fallback used when the session component is empty. Without it,
# file-backed strikes for an empty session would all share a key and leak
# across sessions.
EMPTY_SESSION_FALLBACK = "no-session"

# Notice wording, byte-identical to the Bash emitters it replaces.
LOCAL_YIELD_NOTICE = "Communication Rules unmet after retries, output allowed."
EXTERNAL_YIELD_PREFIX = "Rules breach posted: "
FACING_NOTICE = "Communication Rules breach seen, correcting next reply."

# Short B2 nudge for the middle blocks of the external cap. The first and the
# penultimate block re-issue the full rules; the blocks in between emit this
# instead, since the rules are already in context. The dispatcher promotes this
# notice to the block message, so every responder emits it as the block reason.
EXTERNAL_REPEAT_NOTICE = "Communication Rules still unmet. Revise the body to comply before posting."

# Scan outcomes the gate accepts. ``pass`` clears the strike, ``block`` walks
# the cap, ``unresolved`` is the fail-closed case (scanner could not decide).
SCAN_PASS = "pass"
SCAN_BLOCK = "block"
SCAN_UNRESOLVED = "unresolved"


def _runtime_root() -> str:
    base = os.environ.get("XDG_RUNTIME_DIR") or os.environ.get("TMPDIR") or "/tmp"
    return os.path.join(base, "agent-communication-rules")


def _session_component(session: str) -> str:
    # Guarantee a non-empty session component before file-backing strikes. An
    # empty session id otherwise shares one key across unrelated sessions.
    return session if session else EMPTY_SESSION_FALLBACK


def _local_strike_limit() -> int:
    # Read the effective B1 limit. The test-only ``TRIPWIRE_LOCAL_STRIKE_LIMIT``
    # env override lets a live A/B flip modes without editing source; it wins
    # only when it parses as a positive integer. The ``LOCAL_STRIKE_LIMIT``
    # constant stays the single source of the default.
    raw = os.environ.get("TRIPWIRE_LOCAL_STRIKE_LIMIT")
    if raw is not None:
        text = raw.strip()
        if text.isdigit():
            value = int(text)
            if value > 0:
                return value
    return LOCAL_STRIKE_LIMIT


def _external_strike_limit() -> int:
    # Read the effective B2 cap. The test-only ``TRIPWIRE_EXTERNAL_STRIKE_LIMIT``
    # env override lets a test exercise the re-issue trim at a smaller cap without
    # editing source; it wins only when it parses as an integer of at least two
    # (a cap below two cannot block before it yields). The ``EXTERNAL_STRIKE_LIMIT``
    # constant stays the single source of the default, mirroring the B1 reader.
    raw = os.environ.get("TRIPWIRE_EXTERNAL_STRIKE_LIMIT")
    if raw is not None:
        text = raw.strip()
        if text.isdigit():
            value = int(text)
            if value >= 2:
                return value
    return EXTERNAL_STRIKE_LIMIT


def strike_key(record: ExtractorRecord, surface: str) -> str:
    """Join the strike key from the record, mirroring the four adapters.

    B1 keys on session + (turn) + tool + target. B2 keys on the ``external``
    namespace + session + (turn) + tool, with no target, so reworded retries of
    the same logical post share one budget. Codex includes ``turn``; the other
    three omit it. The key is a sha256 hex digest, matching the Bash and Python
    key shape.
    """
    session = _session_component(record.session)
    if surface == "external":
        parts = [EXTERNAL_NAMESPACE, session]
        if record.turn is not None:
            parts.append(record.turn)
        parts.append(record.tool)
    else:
        parts = [session]
        if record.turn is not None:
            parts.append(record.turn)
        parts.append(record.tool)
        parts.append(record.target or "")
    raw = "\0".join(parts)
    return hashlib.sha256(raw.encode("utf-8", "replace")).hexdigest()


def _strike_dir(agent: str) -> str:
    # Honour the existing per-agent env overrides so fixtures point the strike
    # root at a temp dir. Claude Code and Codex keep their historical names;
    # Pi and OpenCode gain the per-agent equivalents introduced by the
    # file-backed move. A generic override applies to any agent.
    per_agent = {
        "claude-code": "TRIPWIRE_CLAUDE_CODE_STRIKE_DIR",
        "codex": "TRIPWIRE_RETRY_DIR",
        "pi": "TRIPWIRE_PI_STRIKE_DIR",
        "opencode": "TRIPWIRE_OPENCODE_STRIKE_DIR",
    }
    name = per_agent.get(agent)
    if name and os.environ.get(name):
        return os.environ[name]
    generic = os.environ.get("TRIPWIRE_STRIKE_DIR")
    if generic:
        return generic
    return os.path.join(_runtime_root(), f"{agent}-pretooluse-strikes")


def _strike_file(agent: str, key: str) -> Path | None:
    # Only a well-formed 64-hex key names a count file; anything else falls back
    # to a single shared "fallback" file, matching the Bash guard.
    if not re.fullmatch(r"[0-9a-f]{64}", key):
        key = "fallback"
    root = Path(_strike_dir(agent))
    try:
        root.mkdir(parents=True, exist_ok=True)
    except OSError:
        return None
    return root / f"{key}.count"


def _record_strike(agent: str, key: str) -> int:
    count_file = _strike_file(agent, key)
    if count_file is None:
        return 1
    old = 0
    try:
        text = count_file.read_text(encoding="utf-8").strip()
        if text.isdigit():
            old = int(text)
    except OSError:
        old = 0
    count = old + 1
    try:
        count_file.write_text(f"{count}\n", encoding="utf-8")
    except OSError:
        pass
    return count


def _reset_strike(agent: str, key: str) -> None:
    count_file = _strike_file(agent, key)
    if count_file is None:
        return
    try:
        count_file.unlink()
    except OSError:
        pass


def _reissue_dir(agent: str) -> str:
    per_agent = {
        "claude-code": "TRIPWIRE_CLAUDE_CODE_REISSUE_DIR",
        "pi": "TRIPWIRE_PI_REISSUE_DIR",
        "opencode": "TRIPWIRE_OPENCODE_REISSUE_DIR",
    }
    name = per_agent.get(agent)
    if name and os.environ.get(name):
        return os.environ[name]
    generic = os.environ.get("TRIPWIRE_REISSUE_DIR")
    if generic:
        return generic
    if agent == "codex":
        # Codex nests the reissue flags under its strike dir, mirroring the
        # CODEX_REISSUE_SUBDIR layout.
        return os.path.join(_strike_dir(agent), "reissue")
    return os.path.join(_runtime_root(), f"{agent}-pending-reissue")


def _reissue_file(agent: str, session: str) -> Path | None:
    safe = re.sub(r"[^A-Za-z0-9_.-]", "_", session)
    if not safe:
        safe = "fallback"
    root = Path(_reissue_dir(agent))
    try:
        root.mkdir(parents=True, exist_ok=True)
    except OSError:
        return None
    return root / f"{safe}.flag"


def set_pending_reissue(agent: str, session: str) -> None:
    """Write the Tier A pending-reissue flag for this session."""
    flag = _reissue_file(agent, session)
    if flag is None:
        return
    try:
        flag.touch()
    except OSError:
        pass


def take_pending_reissue(agent: str, session: str) -> bool:
    """Read and clear the pending-reissue flag. True when one was set.

    This is the read-and-clear half of the Tier A re-issue-once contract: the
    facing breach wrote the flag, this call consumes it exactly once.
    """
    flag = _reissue_file(agent, session)
    if flag is None or not flag.exists():
        return False
    try:
        flag.unlink()
    except OSError:
        pass
    return True


def _injected_dir(agent: str) -> str:
    generic = os.environ.get("TRIPWIRE_INJECTED_DIR")
    if generic:
        return generic
    return os.path.join(_runtime_root(), f"{agent}-injected-rules")


def _injected_file(agent: str, session: str) -> Path | None:
    safe = re.sub(r"[^A-Za-z0-9_.-]", "_", _session_component(session))
    root = Path(_injected_dir(agent))
    try:
        root.mkdir(parents=True, exist_ok=True)
    except OSError:
        return None
    return root / f"{safe}.flag"


def should_inject_base_rules(agent: str, session: str) -> bool:
    """Return True once per session, then record that rules were injected.

    Replaces the in-process ``injectedSystemKeys``/``hasInjectedRules`` state
    the TS shims held. File-backed and session-scoped, so the dedupe now
    survives a runtime restart, the accepted behaviour drift in the proposal.
    """
    flag = _injected_file(agent, session)
    if flag is None:
        return True
    if flag.exists():
        return False
    try:
        flag.touch()
    except OSError:
        pass
    return True


def gate(
    agent: str,
    record: ExtractorRecord,
    surface: str,
    scan: str,
    existing_blocked: bool = False,
) -> Decision:
    """Decide a gating (Tier B) surface: pass, block, or yield.

    ``surface`` is ``local`` (B1) or ``external`` (B2); the core picks the limit
    and the key namespace from it. ``scan`` is one of ``pass``, ``block``, or
    ``unresolved``. A clean pass resets the strike for this surface and returns
    pass. A block or an unresolved scan (fail-closed) walks the cap: the first
    strikes block, the limit-th yields and resets. A duplicate breach in the
    same turn (``existing_blocked``) takes no second strike and no second
    notice.
    """
    is_external = surface == "external"
    key = strike_key(record, surface)

    if scan == SCAN_PASS:
        _reset_strike(agent, key)
        return Decision(
            decision="pass",
            surface="B2" if is_external else "B1",
            notice="",
            level="warning",
            inject_base_rules=False,
            append_correction=False,
        )

    # A duplicate breach already handled this turn: no second strike, no second
    # notice. Mirror the Bash early-exit, which emits nothing.
    if existing_blocked:
        return Decision(
            decision="block",
            surface="B2" if is_external else "B1",
            notice="",
            level="warning" if not is_external else "error",
            inject_base_rules=False,
            append_correction=False,
        )

    if not is_external:
        # B1: block once, then allow-and-revise. Strike 1 (up to the effective
        # limit) blocks; every later strike allows the write to land and asks
        # for an in-place revision of the named target. No reset here: the count
        # must keep climbing so each later breach re-emits. Only a clean scan
        # (the SCAN_PASS branch above) resets it.
        strike = _record_strike(agent, key)
        if strike <= _local_strike_limit():
            return Decision(
                decision="block",
                surface="B1",
                notice="",
                level="warning",
                inject_base_rules=False,
                append_correction=False,
            )
        # ``notice`` here carries the raw target for the dispatcher to resolve
        # into the B1 revision prompt; it is not final user text.
        return Decision(
            decision="allow-revise",
            surface="B1",
            notice=record.target or "",
            level="warning",
            inject_base_rules=False,
            append_correction=False,
        )

    limit = _external_strike_limit()
    notice = EXTERNAL_YIELD_PREFIX + (record.target or record.tool)
    level = "error"

    strike = _record_strike(agent, key)
    if strike >= limit:
        _reset_strike(agent, key)
        return Decision(
            decision="yield",
            surface="B2",
            notice=notice,
            level=level,
            inject_base_rules=False,
            append_correction=False,
        )

    # Re-issue the full rules on the first and the penultimate block only; emit
    # the short nudge on the blocks in between. The rules are already in context
    # from the first block, so the middle repeats add tokens without new
    # information. An empty notice falls through to the full block message in the
    # dispatcher; the nudge notice is promoted to the block message there. This
    # degrades cleanly: for a limit of 2 or 3 the range ``1 < strike < limit - 1``
    # is empty, so every block keeps the full message.
    block_notice = EXTERNAL_REPEAT_NOTICE if 1 < strike < limit - 1 else ""
    return Decision(
        decision="block",
        surface="B2",
        notice=block_notice,
        level=level,
        inject_base_rules=False,
        append_correction=False,
    )


def facing(
    agent: str,
    record: ExtractorRecord,
    scan: str,
    existing_blocked: bool = False,
) -> Decision:
    """Decide a Tier A facing surface (Stop / SubagentStop): never block.

    A clean pass clears any stale pending flag so a later good turn is not
    re-issued against. A breach (or fail-closed unresolved scan) sets the
    pending-reissue flag and returns a notice; the next UserPromptSubmit re-
    issues the rules. A duplicate breach in the same turn stays silent.
    """
    if scan == SCAN_PASS:
        take_pending_reissue(agent, record.session)
        return Decision(
            decision="pass",
            surface="tierA",
            notice="",
            level="warning",
            inject_base_rules=False,
            append_correction=False,
        )

    if existing_blocked:
        return Decision(
            decision="block",
            surface="tierA",
            notice="",
            level="warning",
            inject_base_rules=False,
            append_correction=False,
        )

    set_pending_reissue(agent, record.session)
    return Decision(
        decision="block",
        surface="tierA",
        notice=FACING_NOTICE,
        level="warning",
        inject_base_rules=False,
        append_correction=False,
    )


def reissue(agent: str, record: ExtractorRecord) -> Decision:
    """Decide a UserPromptSubmit re-issue: clear the flag and re-issue once.

    Reads and clears the pending-reissue flag. When one was set, returns a
    ``re-issue`` decision with ``append_correction`` so the responder injects
    the correction prompt. Otherwise returns pass.
    """
    if take_pending_reissue(agent, record.session):
        return Decision(
            decision="re-issue",
            surface="tierA",
            notice="",
            level="warning",
            inject_base_rules=False,
            append_correction=True,
        )
    return Decision(
        decision="pass",
        surface="tierA",
        notice="",
        level="warning",
        inject_base_rules=False,
        append_correction=False,
    )


def reminder(agent: str, record: ExtractorRecord) -> Decision:
    """Decide a SessionStart / SubagentStart reminder: inject the rules once.

    The old Bash adapters emitted the rules reminder as ``additionalContext`` on
    every SessionStart and (Codex) SubagentStart, with no per-session dedupe: the
    command hook fires once per session start, so the runtime, not the core,
    bounds it. This keeps that contract. The decision verb is ``remind``; the
    responder formats the reminder text into the agent's context shape. ``record``
    is unused but kept for a uniform state-machine signature.
    """
    return Decision(
        decision="remind",
        surface="tierA",
        notice="",
        level="warning",
        inject_base_rules=True,
        append_correction=False,
    )


def context(agent: str, record: ExtractorRecord) -> Decision:
    """Decide a Pi context build: inject base rules once, re-issue when pending.

    Pi has no separate UserPromptSubmit hook; its context handler does both
    Tier A jobs the core owns. ``inject_base_rules`` fires once per session
    (the file-backed dedupe replacing the in-process ``hasInjectedRules``).
    ``append_correction`` fires when a facing breach left a pending-reissue
    flag, which this read clears. The shim applies both flags to the live
    ``event.messages``; it holds no policy. The decision stays a pass: a
    context build never blocks or yields.
    """
    return Decision(
        decision="pass",
        surface="tierA",
        notice="",
        level="warning",
        inject_base_rules=should_inject_base_rules(agent, record.session),
        append_correction=take_pending_reissue(agent, record.session),
    )
