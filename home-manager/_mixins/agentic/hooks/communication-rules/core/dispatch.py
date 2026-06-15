"""Dispatch an ``<agent> <event>`` invocation to the core.

This module is the seam between the CLI in ``scanner.py`` and the core. It
reads the agent event JSON on stdin, runs the shared middle, and writes the
decision JSON on stdout.

The shared middle is real plumbing: a per-agent extractor returns a normalised
record plus a routing decision; the dispatcher runs detection on that record,
``core.state`` decides the verb, and ``core.responses`` shapes the output. The
per-agent extractors are stubs until their own migration phases; the path they
flow through is not.

The dispatcher holds no policy (that lives in ``core.state``) and no detection
rules (those live in ``core.detection``). The one piece of logic here is
plumbing: the bash-routing guard that sends a Bash tool call's command text
through ``detection.scan_bash`` and never through an adapter's parallel gh-post
detection. See ``_run_scan``.
"""

from __future__ import annotations

import json
import sys
from dataclasses import asdict, dataclass

from core import responses, state
from core.config import Config
from core.detection import scan_bash, scan_prose
from core.types import Decision, ExtractorRecord

# The fixed set of agents the dispatch form accepts. Validated against the
# first positional so an agent name never collides with a subcommand.
AGENTS = ("claude-code", "codex", "pi", "opencode")

# Event-class verbs an extractor tags a record with, so the shared middle knows
# which state-machine entry to call. ``gate`` is a Tier B PreToolUse surface;
# ``facing`` is a Tier A Stop / SubagentStop surface; ``reissue`` is the Tier A
# UserPromptSubmit re-issue; ``context`` is the Pi context build that injects the
# base rules once and re-issues the correction when pending; ``pass`` is a
# non-gating event the core ignores.
EVENT_GATE = "gate"
EVENT_FACING = "facing"
EVENT_REISSUE = "reissue"
EVENT_CONTEXT = "context"
EVENT_REMINDER = "reminder"
EVENT_PASS = "pass"

# How the shared middle scans the record body. ``bash`` routes through
# ``scan_bash``; ``text`` routes each text through ``scan_prose``; ``none`` runs
# no detection (used by the re-issue event, which carries no body).
SCAN_BASH = "bash"
SCAN_TEXT = "text"
SCAN_NONE = "none"


@dataclass
class Extraction:
    """What a per-agent extractor hands the shared middle.

    The extractor reads raw agent JSON and fills this. The shared middle and the
    state machine touch only this, never raw agent JSON.

    - ``record``: the normalised :class:`ExtractorRecord`.
    - ``event_class``: ``gate`` | ``facing`` | ``reissue`` | ``context`` |
      ``reminder`` | ``pass``.
    - ``surface``: ``local`` | ``external`` for a gate event; ignored otherwise.
      The state machine picks the limit and key namespace from it.
    - ``scan_mode``: ``bash`` | ``text`` | ``none``. ``bash`` forces the
      command text through ``scan_bash``; ``text`` runs ``scan_prose`` on each
      text. The extractor never scans; it only routes.
    - ``unresolved``: True when the extractor could not resolve the body to
      scan (a broken payload, an unreadable file, a dynamic post body). On a
      gating surface this maps to the state machine's fail-closed path; it never
      passes.
    - ``existing_blocked``: True when this turn already raised a breach, so the
      state machine takes no second strike and no second notice.
    """

    record: ExtractorRecord
    event_class: str = EVENT_PASS
    surface: str = "local"
    scan_mode: str = SCAN_NONE
    unresolved: bool = False
    existing_blocked: bool = False


def pass_decision() -> Decision:
    """Return a pass decision with no notice and no Tier A injection."""
    return Decision(
        decision="pass",
        surface="tierA",
        notice="",
        level="warning",
        inject_base_rules=False,
        append_correction=False,
    )


def decision_to_json(decision: Decision) -> str:
    """Serialise a ``Decision`` to a stable one-line JSON string."""
    return json.dumps(asdict(decision), sort_keys=True)


def read_event(stream: object | None = None) -> dict:
    """Read and parse the event JSON on stdin.

    Returns an empty dict when stdin is empty or not valid JSON, so the
    dispatcher never raises on a malformed payload.
    """
    source = stream if stream is not None else sys.stdin
    raw = source.read()
    if not raw.strip():
        return {}
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        return {}
    return parsed if isinstance(parsed, dict) else {}


def _stub_extract(agent: str, event: str, payload: dict) -> Extraction:
    """Stub per-agent extraction: a minimal, real-shaped routing record.

    The real per-agent extractors arrive in their migration phases. This stub
    fills the plumbing so the shared middle is exercised end to end: it reads
    the common ``tool_name`` / ``tool_input`` shape, tags a Bash tool call as a
    gate event scanned through ``scan_bash``, and otherwise returns a pass. It
    holds no per-agent payload knowledge beyond this common shape.
    """
    session = payload.get("session_id")
    record = ExtractorRecord(
        session=session if isinstance(session, str) else "",
        turn=None,
        tool="",
        target=None,
        texts=[],
    )

    tool_name = payload.get("tool_name")
    tool_input = payload.get("tool_input")
    if isinstance(tool_name, str) and tool_name == "Bash" and isinstance(tool_input, dict):
        command = tool_input.get("command")
        if isinstance(command, str):
            record.tool = "Bash"
            record.texts = [command]
            # The stub classifies surface from the same command string the
            # adapters classify on; the BODY still routes through scan_bash. A
            # gh/gh-api-safe post is external (B2), everything else local (B1).
            surface = "external" if _looks_like_external_bash(command) else "local"
            return Extraction(
                record=record,
                event_class=EVENT_GATE,
                surface=surface,
                scan_mode=SCAN_BASH,
            )

    # Every other stubbed event is a pass until the real extractor lands.
    return Extraction(record=record, event_class=EVENT_PASS, scan_mode=SCAN_NONE)


def _extract(agent: str, event: str, payload: dict, config: Config | None) -> Extraction:
    """Route extraction to the real per-agent extractor, else the stub.

    Migrated agents have a real extractor module under ``core.extractors``; the
    rest still use the common-shape stub until their migration phase. The
    extractor is imported lazily so ``core.extractors.*`` can import the
    ``Extraction`` dataclass and the routing constants from this module without a
    circular import at module load.
    """
    # The extractor needs a config to read the post-detection lists and to
    # classify the surface. When no policy loaded, pass a minimal config; the
    # dispatcher still marks a gating event unresolved afterwards, so the
    # fallback lists never decide a live gate.
    extractor_config = config if config is not None else _empty_config()

    if agent == "claude-code":
        from core.extractors import claude_code

        return claude_code.extract(event, payload, extractor_config)

    if agent == "codex":
        from core.extractors import codex

        return codex.extract(event, payload, extractor_config)

    if agent == "pi":
        from core.extractors import pi

        return pi.extract(event, payload, extractor_config)

    if agent == "opencode":
        from core.extractors import opencode

        return opencode.extract(event, payload, extractor_config)

    return _stub_extract(agent, event, payload)


def _looks_like_external_bash(command: str) -> bool:
    """Surface-only classification of a Bash command: external versus local.

    This is the SURFACE CHOICE, not body detection. It mirrors the adapters'
    external-surface check (``adapters/claude-code.py`` lines 220-268): a
    ``gh`` / ``gh-api-safe`` first token plus a post signal is external (B2).
    The command body is NEVER scanned here; that goes through ``scan_bash`` in
    ``_run_scan``. Keeping the two apart is the proposal's bash-routing rule.
    """
    argv = command.split()
    if not argv or argv[0] not in {"gh", "gh-api-safe"}:
        return False
    post_flags = {
        "-b",
        "--body",
        "-F",
        "--body-file",
        "-f",
        "--field",
        "--raw-field",
        "--notes",
        "-m",
        "--message",
        "-t",
        "--title",
    }
    for index, token in enumerate(argv):
        if token in post_flags:
            return True
        if token.startswith(("--body=", "--body-file=", "--field=", "--raw-field=")):
            return True
        if token.startswith(("--notes=", "--message=", "--title=")):
            return True
        if token in {"-X", "--method"} and index + 1 < len(argv):
            if argv[index + 1].upper() in {"POST", "PATCH", "PUT"}:
                return True
        if token.startswith("--method=") and token.split("=", 1)[1].upper() in {"POST", "PATCH", "PUT"}:
            return True
        if token == "--input" or token.startswith("--input="):
            return True
    return False


def _run_scan(extraction: Extraction, config: Config) -> str:
    """Run detection on the extracted record and return the scan outcome.

    Returns one of ``state.SCAN_PASS``, ``state.SCAN_BLOCK``,
    ``state.SCAN_UNRESOLVED``. An extractor that could not resolve a body to
    scan sets ``unresolved``, which fails closed here.

    GUARD (Flag: needs review): a Bash tool call routes its command text through
    ``detection.scan_bash`` ONLY. Live agent bash never uses an adapter's
    parallel gh-post detection (``is_bash_gh_post`` in ``adapters/claude-code.py``,
    ``post_command`` / ``patch_text`` in ``adapters/pi.py``). Those adapter paths
    inform the SURFACE CHOICE only; the BODY detection is ``scan_bash`` here, so
    the a6496fc7 pipe fix and the redirect / heredoc coverage apply to live
    traffic, not only the ``scan-bash`` fixture subcommand.
    """
    if extraction.unresolved:
        return state.SCAN_UNRESOLVED

    if extraction.scan_mode == SCAN_NONE:
        return state.SCAN_PASS

    if extraction.scan_mode == SCAN_BASH:
        blocked = any(scan_bash(text, config) for text in extraction.record.texts)
        return state.SCAN_BLOCK if blocked else state.SCAN_PASS

    # SCAN_TEXT: prose tools and post bodies.
    blocked = any(scan_prose(text, config, strip_fences=True) for text in extraction.record.texts)
    return state.SCAN_BLOCK if blocked else state.SCAN_PASS


def _decide(agent: str, extraction: Extraction, config: Config) -> Decision:
    """Run the shared middle: scan, then route to the right state-machine entry."""
    if extraction.event_class == EVENT_PASS:
        return pass_decision()

    if extraction.event_class == EVENT_REISSUE:
        # The re-issue event carries no body; it only reads and clears the
        # pending flag.
        return state.reissue(agent, extraction.record)

    if extraction.event_class == EVENT_CONTEXT:
        # The Pi context build carries no body; the core decides whether to
        # inject the base rules (once per session) and whether to re-issue the
        # correction (a pending facing breach). The shim applies the flags.
        return state.context(agent, extraction.record)

    if extraction.event_class == EVENT_REMINDER:
        # SessionStart / SubagentStart for the command-hook agents: inject the
        # rules reminder as additionalContext, matching the old Bash adapters.
        return state.reminder(agent, extraction.record)

    scan = _run_scan(extraction, config)

    if extraction.event_class == EVENT_FACING:
        return state.facing(agent, extraction.record, scan, extraction.existing_blocked)

    # EVENT_GATE: Tier B PreToolUse.
    return state.gate(
        agent,
        extraction.record,
        extraction.surface,
        scan,
        extraction.existing_blocked,
    )


def dispatch(agent: str, event: str, config: Config | None) -> Decision:
    """Route an ``<agent> <event>`` invocation through the core.

    Reads the event JSON on stdin, extracts a normalised record, scans it,
    decides, and returns the decision. The per-agent extractors are stubs until
    their phases; the path through detection, state, and the responder is real.

    A missing config fails closed on a gating surface: the dispatcher cannot
    scan without the policy, so it treats the body as unresolved rather than
    passing it.
    """
    payload = read_event()
    extraction = _extract(agent, event, payload, config)
    if config is None and extraction.event_class in {EVENT_GATE, EVENT_FACING}:
        extraction.unresolved = True
    # A None config still has to drive the state machine for the fail-closed
    # case, so synthesise a minimal one only for detection-free routing.
    decision_config = config if config is not None else _empty_config()
    return _decide(agent, extraction, decision_config)


def _empty_config() -> Config:
    """A minimal config for the fail-closed path when no policy loaded.

    Detection never runs against it (the gating event is already marked
    unresolved), but the state machine signature expects a real type.
    """
    return Config(rules_text="", reminder_prompt=None, block_message=None, policy={})


def shape_response(agent: str, event: str, decision: Decision, config: Config | None) -> dict | None:
    """Turn a decision into the agent's wire shape via ``core.responses``.

    Resolves the block message, the correction prompt, and the reminder text
    from config (content, not policy) and hands them to the responder. Command
    agents (Claude Code, Codex) get a dict to serialise; plugin agents (Pi,
    OpenCode) get the flat data dict their shim relays. Returns ``None`` for a
    silent command-agent outcome (a pass, or a duplicate breach in the turn).

    ``event`` is the agent event name. Codex carries the reminder on the
    SessionStart / SubagentStart event name, so the responder needs it. Claude
    Code fixes each event name in its own responder, so it ignores ``event``.

    The correction (the UserPromptSubmit re-issue) and the reminder (the
    SessionStart / SubagentStart injection) are DISTINCT texts: the old Bash
    adapters used ``tripwire_emit_correction`` for the re-issue and
    ``tripwire_emit_reminder`` for the reminder. They were conflated here, which
    sent the reminder where the correction belonged.

    An ``allow-revise`` decision (B1 strike >= 2) carries the RAW target in
    ``decision.notice`` (the gate placed ``record.target or ""`` there). This
    resolves the B1 revision prompt and substitutes the concrete target before
    the responder sees it, so the final user-facing notice never contains a
    literal ``{target}``. The ``allow-revise`` verb flows through unchanged to
    every responder: the command responders shape it as an allow + reason, and
    the plugin agents relay the verb with the resolved notice.
    """
    block_message = config.block_message if config is not None else ""
    correction = config.correction_prompt if config is not None else ""
    reminder = config.reminder_prompt if config is not None else ""
    if decision.decision == "allow-revise":
        revision_prompt = config.b1_revision_prompt if config is not None else ""
        decision.notice = _resolve_revision_notice(revision_prompt, decision.notice)
    if agent == "claude-code":
        return responses.claude_code_response(decision, block_message, correction, reminder)
    if agent == "codex":
        return responses.codex_response(decision, block_message, correction, reminder, event)
    # Pi and OpenCode share the plugin response shape.
    return responses.plugin_response(decision, block_message, correction)


# Marker the B1 revision prompt may use for the concrete target. Substituted
# with the resolved path; stripped entirely when no target is known, so the
# final notice never carries a literal ``{target}``.
_TARGET_PLACEHOLDER = "{target}"

# Generic B1 revision notice used when no concrete target is known (a Bash B1
# breach has an empty target). It names no file and carries no placeholder.
_GENERIC_REVISION_NOTICE = "Revise the prose you just wrote to comply with the Communication Rules."


def _resolve_revision_notice(prompt: str, raw_target: str) -> str:
    """Resolve a B1 revision prompt into the final ``allow-revise`` notice.

    ``raw_target`` is the gate-supplied ``record.target or ""``. When it is
    non-empty, every ``{target}`` occurrence in ``prompt`` is replaced with it.
    When it is empty, the prompt degrades to the baked generic sentence, which
    names no file and carries no placeholder, so no dangling ``comply: .``
    fragment can leak from a half-stripped template.

    CRITICAL: the result must never contain the literal ``{target}``. The
    non-empty path substitutes every occurrence; the empty path returns a fixed
    sentence; and a final guard strips any placeholder that still survives, so a
    malformed prompt can never leak one.
    """
    target = raw_target.strip()
    if target:
        resolved = prompt.replace(_TARGET_PLACEHOLDER, target)
    else:
        # No concrete target (a Bash B1 breach): use the baked generic sentence
        # rather than a half-stripped template that leaves dangling punctuation.
        resolved = _GENERIC_REVISION_NOTICE
    # Final guard: never let a literal placeholder escape, whatever the prompt.
    return resolved.replace(_TARGET_PLACEHOLDER, "").strip() if _TARGET_PLACEHOLDER in resolved else resolved
