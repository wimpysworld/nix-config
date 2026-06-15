"""Per-agent decision shaping.

A responder turns an already-decided ``Decision`` into the output its agent
expects. Responders never compute policy: ``core.state`` decides the verb, the
surface, the notice, the level, and the Tier A injection flags; a responder
only formats that decision into the agent's wire shape.

Two response families exist, matching the two adapter families:

- Command agents (Claude Code, Codex) read a JSON decision on stdout. Their
  responders return the exact ``hookSpecificOutput`` / ``systemMessage``
  payloads the old Bash emitters printed (``claude-code.sh`` and ``codex.sh``).
  The caller serialises the dict to JSON.
- Plugin agents (Pi, OpenCode) load an in-process shim. Their responders return
  a plain data dict the shim relays: the verb, the surface, the level, the
  notice, the Tier A injection flags, and the correction text. The shim, not
  the responder, applies those to the live runtime objects (``output.system``,
  ``output.text``, ``event.messages``) and calls the toast/notify. That
  live-object write is the one named exception to "zero logic in TS"; it is
  runtime glue, not policy.

Each responder is a pure function of its ``Decision`` plus the minimal text it
needs (the block message and the correction prompt are content, resolved by the
dispatcher, not policy a responder recomputes). No cross-talk between agents.
"""

from __future__ import annotations

from core.types import Decision


# --- Command agents: Claude Code -------------------------------------------
#
# Mirror the emitters in ``adapters/claude-code.sh``:
# - deny  -> hookSpecificOutput.permissionDecision = "deny"  (claude-code.sh:144-165)
# - allow -> hookSpecificOutput.permissionDecision = "allow" (claude-code.sh:167-189)
# - Tier A facing notice -> {"systemMessage": notice}        (claude-code.sh:294-303)
# - re-issue -> hookSpecificOutput.additionalContext         (claude-code.sh:317-342)


def claude_code_deny(block_message: str) -> dict:
    """The PreToolUse deny payload. The reason re-issues the rules to the model.

    The deny reason is the block message (the old ``tripwire_emit_block_once``),
    not ``decision.notice``: a block carries no notice. The dispatcher resolves
    the block message text and passes it in.
    """
    return {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": block_message,
        }
    }


def claude_code_allow(decision: Decision) -> dict:
    """The PreToolUse allow (yield) payload carrying the user-facing notice.

    The yield notice is ``decision.notice``: the short B1 notice or the B2
    operator notice naming the tool and target. The state machine baked the full
    text, so the responder copies it verbatim.
    """
    return {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "allow",
            "permissionDecisionReason": decision.notice,
        }
    }


def claude_code_facing(decision: Decision) -> dict:
    """The Tier A facing notice on Stop / SubagentStop: a top-level systemMessage."""
    return {"systemMessage": decision.notice}


def claude_code_reissue(correction: str) -> dict:
    """The UserPromptSubmit re-issue: the correction prompt as additionalContext.

    The correction text is content the dispatcher resolves (the correction
    prompt file, with the baked fallback), not policy. The responder only places
    it in the additionalContext shape.
    """
    return {
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": correction,
        }
    }


def claude_code_reminder(reminder: str) -> dict:
    """The SessionStart reminder: the rules reminder as additionalContext.

    The old ``claude-code.sh`` emitted the reminder as raw stdout text on
    SessionStart. That predates the strict hook-output schema and now fails
    validation alongside the other events. Emitting the reminder as
    ``hookSpecificOutput.additionalContext`` carries the same model-facing
    reminder text in a shape the runtime validates and injects as context.
    """
    return {
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": reminder,
        }
    }


def claude_code_response(
    decision: Decision,
    block_message: str,
    correction: str,
    reminder: str = "",
) -> dict | None:
    """Shape a Claude Code decision into its emitted payload.

    Returns ``None`` for a silent outcome (a pass, or a duplicate breach in the
    same turn): the old Bash emitters wrote nothing in those cases. The caller
    emits nothing when this returns ``None``.
    """
    if decision.decision == "remind":
        return claude_code_reminder(reminder)
    if decision.decision == "block":
        # A Tier A facing breach carries the facing notice and emits a
        # systemMessage so the turn ends with the user notice (the old
        # emit_facing_notice_and_exit). The duplicate-breach early-exit carries
        # an empty notice and emits nothing (the Bash silent path). A Tier B
        # gating block re-issues the rules via the deny reason.
        if decision.surface == "tierA":
            if decision.notice:
                return claude_code_facing(decision)
            return None
        return claude_code_deny(block_message)
    if decision.decision == "yield":
        if decision.surface == "tierA":
            # Tier A never yields a tool call; a facing breach is a systemMessage.
            return claude_code_facing(decision)
        return claude_code_allow(decision)
    if decision.decision == "re-issue":
        return claude_code_reissue(correction)
    # A pass emits nothing.
    return None


# --- Command agents: Codex --------------------------------------------------
#
# Mirror the emitters in ``adapters/codex.sh``:
# - deny  -> hookSpecificOutput.permissionDecision = "deny"  (codex.sh:62-69)
# - allow -> hookSpecificOutput.permissionDecision = "allow" (codex.sh:71-78)
# - context (reminder / re-issue) -> hookSpecificOutput.additionalContext (codex.sh:44-55)
# - Tier A facing notice -> {"systemMessage": notice}        (codex.sh:136-142)
#
# The shapes match Claude Code key-for-key; the only divergence is that Codex
# carries the re-issue on a named event via codex_emit_context.


def codex_deny(block_message: str) -> dict:
    """The Codex PreToolUse deny payload (codex.sh:62-69)."""
    return {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": block_message,
        }
    }


def codex_allow(decision: Decision) -> dict:
    """The Codex PreToolUse allow (yield) payload (codex.sh:71-78)."""
    return {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "allow",
            "permissionDecisionReason": decision.notice,
        }
    }


def codex_facing(decision: Decision) -> dict:
    """The Codex Tier A facing notice: a top-level systemMessage (codex.sh:136-142)."""
    return {"systemMessage": decision.notice}


def codex_context(event_name: str, context_text: str) -> dict:
    """The Codex additionalContext emit for a named event (codex.sh:44-55).

    Used for the UserPromptSubmit re-issue (and the reminder emit). The event
    name rides in the payload, unlike Claude Code which fixes UserPromptSubmit.
    """
    return {
        "hookSpecificOutput": {
            "hookEventName": event_name,
            "additionalContext": context_text,
        }
    }


def codex_response(
    decision: Decision,
    block_message: str,
    correction: str,
    reminder: str = "",
    event_name: str = "UserPromptSubmit",
) -> dict | None:
    """Shape a Codex decision into its emitted payload.

    Returns ``None`` for a silent outcome (pass, or a duplicate breach in the
    same turn). ``event_name`` names the event a re-issue or reminder rides on:
    UserPromptSubmit for the re-issue, SessionStart / SubagentStart for the
    reminder. Codex carries both on ``additionalContext`` under that event name,
    matching the old ``codex_emit_context``.
    """
    if decision.decision == "remind":
        return codex_context(event_name, reminder)
    if decision.decision == "block":
        # A Tier A facing breach (non-empty notice) emits a systemMessage; the
        # duplicate-breach early-exit (empty notice) emits nothing. A Tier B
        # gating block re-issues the rules via the deny reason.
        if decision.surface == "tierA":
            if decision.notice:
                return codex_facing(decision)
            return None
        return codex_deny(block_message)
    if decision.decision == "yield":
        if decision.surface == "tierA":
            return codex_facing(decision)
        return codex_allow(decision)
    if decision.decision == "re-issue":
        return codex_context(event_name, correction)
    return None


# --- Plugin agents: Pi and OpenCode ----------------------------------------
#
# Pi and OpenCode load an in-process shim that returns/throws and mutates live
# runtime objects. A subprocess core cannot touch those objects, so the
# responder returns a plain data dict and the shim applies it. The data the
# shim needs is the same for both agents; the shim maps it to its own
# return/throw and live-object writes.
#
# Pi return shapes (pi/extensions/communication-rules/index.ts:432-492):
# - tool_call block  -> { block: true, reason }
# - tool_result block -> { content: [...], isError: true }
# - context           -> append messages (base rules, correction)
# - facing            -> ctx.ui.notify(notice, level)
#
# OpenCode return shapes (opencode/plugins/communication-rules.ts:615-687):
# - tool.execute.before block -> throw new Error(reason)
# - tool.execute.before yield -> toastNotice(notice)
# - chat.system.transform     -> push rules / correction onto output.system
# - text.complete             -> appendFacingNotice(output.text)


def plugin_response(
    decision: Decision,
    block_message: str,
    correction: str,
) -> dict:
    """Shape a decision into the data the Pi / OpenCode shim relays.

    Returns a flat data dict; the shim turns it into the runtime's return/throw
    and applies the Tier A injection to the live objects. The dict carries:

    - ``decision``: the verb (``pass`` | ``block`` | ``yield`` | ``re-issue``).
    - ``surface``: ``tierA`` | ``B1`` | ``B2``, so the shim knows the gating tier.
    - ``level``: ``warning`` | ``error``, the toast/notify level.
    - ``notice``: the user-facing notice (full text, incl. tool plus target on a
      B2 yield); empty on a block or a pass.
    - ``inject_base_rules`` / ``append_correction``: the Tier A injection flags
      the shim applies to the live system array / messages.
    - ``block_message``: the re-issue text for a gating block (the shim uses it
      as the block reason / thrown message).
    - ``correction``: the correction prompt text the shim appends when
      ``append_correction`` is set.

    No policy is recomputed here; every field comes from the decision or from
    text the dispatcher resolved.
    """
    return {
        "decision": decision.decision,
        "surface": decision.surface,
        "level": decision.level,
        "notice": decision.notice,
        "inject_base_rules": decision.inject_base_rules,
        "append_correction": decision.append_correction,
        "block_message": block_message,
        "correction": correction,
    }
