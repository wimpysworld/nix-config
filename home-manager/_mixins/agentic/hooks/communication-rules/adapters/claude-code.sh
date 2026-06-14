#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
contract_path="${TRIPWIRE_ADAPTER_CONTRACT:-$script_dir/contract.sh}"
extractor_path="${TRIPWIRE_CLAUDE_CODE_EXTRACTOR:-$script_dir/claude-code.py}"

# shellcheck source=/dev/null
source "$contract_path"

# Tier B world-output cap, split by blast radius into two sub-tiers. On a
# PreToolUse breach the gate denies the call and feeds the model the rules so it
# retries with compliant content; after the limit the gate yields, allows the
# call, and shows the user a notice. Blocking automation forever is friction
# users will not accept, so each sub-tier denies then yields.
#
# Sub-tier B1 (local: write, edit, bash). Cheap to retract because the output
# lands on disk, not committed. Three-strike-then-yield, keyed on the content
# hash (a fresh path or body is a genuinely fresh action).
LOCAL_STRIKE_LIMIT=3

# Sub-tier B2 (external: post-capable MCP tools). Irretractable the instant it
# yields. Five-strike-then-yield, keyed on a STABLE identity (session + tool) so
# reworded retries of the same logical post draw down one budget, with an
# operator-visible yield notice that names the tool and target.
EXTERNAL_STRIKE_LIMIT=5

payload="$(cat)"
event="${1:-}"

normalise_event() {
  case "$1" in
    remind | session-start | SessionStart)
      printf 'SessionStart\n'
      ;;
    user-prompt-submit | UserPromptSubmit)
      printf 'UserPromptSubmit\n'
      ;;
    pre-tool-use | PreToolUse)
      printf 'PreToolUse\n'
      ;;
    stop | Stop)
      printf 'Stop\n'
      ;;
    subagent-stop | SubagentStop)
      printf 'SubagentStop\n'
      ;;
    "")
      if ! printf '%s' "$payload" | python3 "$extractor_path" event; then
        printf '\n'
      fi
      ;;
    *)
      printf '%s\n' "$1"
      ;;
  esac
}

tripwire_runtime_root() {
  printf '%s\n' "${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/agent-communication-rules"
}

# ---------------------------------------------------------------------------
# Tier B: PreToolUse three-strike-then-yield
# ---------------------------------------------------------------------------

pretooluse_strike_key() {
  printf '%s' "$payload" | python3 "$extractor_path" pretooluse-strike-key 2>/dev/null || true
}

# Surface class for the breached call: "local" (B1) or "external" (B2). Drives
# the strike limit, the strike key, and the yield notice.
pretooluse_surface() {
  printf '%s' "$payload" | python3 "$extractor_path" pretooluse-surface 2>/dev/null || true
}

# Stable B2 strike key (session + tool) so reworded retries of the same logical
# post share one budget.
pretooluse_external_strike_key() {
  printf '%s' "$payload" | python3 "$extractor_path" pretooluse-external-strike-key 2>/dev/null || true
}

# Operator-visible target (PR/issue ref or tool name) for the B2 yield notice.
pretooluse_external_target() {
  printf '%s' "$payload" | python3 "$extractor_path" pretooluse-external-target 2>/dev/null || true
}

# Resolve the strike key for the current surface: the content-hash key for B1
# locals, the stable session+tool key for B2 externals.
pretooluse_active_strike_key() {
  if [[ "$(pretooluse_surface)" == "external" ]]; then
    pretooluse_external_strike_key
  else
    pretooluse_strike_key
  fi
}

pretooluse_strike_file() {
  local key="$1"
  local root

  if [[ ! "$key" =~ ^[0-9a-f]{64}$ ]]; then
    key="fallback"
  fi

  root="${TRIPWIRE_CLAUDE_CODE_STRIKE_DIR:-$(tripwire_runtime_root)/claude-code-pretooluse-strikes}"
  mkdir -p "$root" 2>/dev/null || return 1
  printf '%s/%s.count\n' "$root" "$key"
}

record_pretooluse_strike() {
  local key="$1"
  local count_file
  local count=0
  local old_count=0

  count_file="$(pretooluse_strike_file "$key")" || {
    printf '1\n'
    return 0
  }

  if [[ -r "$count_file" ]]; then
    old_count="$(<"$count_file")"
    case "$old_count" in
      '' | *[!0-9]*)
        old_count=0
        ;;
    esac
  fi
  count=$((old_count + 1))
  printf '%s\n' "$count" >"$count_file" 2>/dev/null || true
  printf '%s\n' "$count"
}

reset_pretooluse_strike() {
  local key="$1"
  local count_file

  count_file="$(pretooluse_strike_file "$key")" || return 0
  rm -f "$count_file" 2>/dev/null || true
}

emit_pretooluse_deny() {
  local reason
  reason="$(tripwire_emit_block_once)"

  # deny stops the tool call; "permissionDecisionReason" is shown to the model,
  # so re-issue the rules there and the model retries with compliant content.
  TRIPWIRE_REASON="$reason" python3 -c '
import json
import os
import sys

reason = os.environ["TRIPWIRE_REASON"]
json.dump({
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": reason,
    }
}, sys.stdout)
'
  exit 0
}

# Emit an allow (yield) decision carrying a user-facing notice. The allow
# "permissionDecisionReason" is user-facing, so it carries the notice. Docs are
# silent on a top-level "systemMessage" co-emit with permissionDecision, so rely
# on the allow reason.
emit_pretooluse_yield() {
  local notice="$1"

  TRIPWIRE_NOTICE="$notice" python3 -c '
import json
import os
import sys

notice = os.environ["TRIPWIRE_NOTICE"]
json.dump({
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "allow",
        "permissionDecisionReason": notice,
    }
}, sys.stdout)
'
  exit 0
}

# Block (deny) or yield (allow) a flagged PreToolUse call by strike count. B1
# locals use the content-hash key and a three-strike limit with a short notice;
# B2 externals use the stable session+tool key and a five-strike limit with an
# operator-visible notice naming the tool and target.
pretooluse_block_or_yield() {
  local surface
  local key
  local limit
  local strike
  local notice

  # Duplicate breach already handled this turn: exit 0 silently.
  if tripwire_existing_blocked; then
    exit 0
  fi

  surface="$(pretooluse_surface)"
  if [[ "$surface" == "external" ]]; then
    key="$(pretooluse_external_strike_key)"
    limit="$EXTERNAL_STRIKE_LIMIT"
    notice="Rules breach posted: $(pretooluse_external_target)"
  else
    key="$(pretooluse_strike_key)"
    limit="$LOCAL_STRIKE_LIMIT"
    notice="Communication Rules unmet after retries, output allowed."
  fi

  strike="$(record_pretooluse_strike "$key")"
  if [[ "$strike" -ge "$limit" ]]; then
    reset_pretooluse_strike "$key"
    emit_pretooluse_yield "$notice"
  fi

  emit_pretooluse_deny
}

scan_file_or_block() {
  local path="$1"
  if tripwire_scan_command scan-file --failure-mode closed "$path" >/dev/null; then
    reset_pretooluse_strike "$(pretooluse_active_strike_key)"
    exit 0
  fi
  pretooluse_block_or_yield
}

scan_bash_or_block() {
  local path="$1"
  local command_text
  command_text="$(<"$path")"
  if tripwire_scan_command scan-bash --failure-mode closed "$command_text" >/dev/null; then
    reset_pretooluse_strike "$(pretooluse_active_strike_key)"
    exit 0
  fi
  pretooluse_block_or_yield
}

# Extraction failure on a world-output surface stays fail-closed: deny or yield
# under the same strike cap rather than letting unscanned prose through.
pretooluse_fail_closed() {
  pretooluse_block_or_yield
}

# ---------------------------------------------------------------------------
# Tier A: Stop / SubagentStop never-block silent re-issue
# ---------------------------------------------------------------------------

pending_reissue_key() {
  printf '%s' "$payload" | python3 "$extractor_path" pending-reissue-key 2>/dev/null || printf 'fallback\n'
}

pending_reissue_file() {
  local key="$1"
  local safe
  local root

  safe="$(printf '%s' "$key" | tr -c 'A-Za-z0-9_.-' '_')"
  if [[ -z "$safe" ]]; then
    safe="fallback"
  fi

  root="${TRIPWIRE_CLAUDE_CODE_REISSUE_DIR:-$(tripwire_runtime_root)/claude-code-pending-reissue}"
  mkdir -p "$root" 2>/dev/null || return 1
  printf '%s/%s.flag\n' "$root" "$safe"
}

set_pending_reissue() {
  local flag_file
  flag_file="$(pending_reissue_file "$(pending_reissue_key)")" || return 0
  : >"$flag_file" 2>/dev/null || true
}

# Tier A facing prose: never block, never re-roll. Emit only a short user notice
# so the turn ends, and set the pending flag so UserPromptSubmit re-issues the
# rules to the model on the next request.
emit_facing_notice_and_exit() {
  local notice="Communication Rules breach seen, correcting next reply."

  # A breach already handled this turn: stay silent to avoid a duplicate notice.
  if tripwire_existing_blocked; then
    exit 0
  fi

  set_pending_reissue
  TRIPWIRE_NOTICE="$notice" python3 -c '
import json
import os
import sys

notice = os.environ["TRIPWIRE_NOTICE"]
json.dump({"systemMessage": notice}, sys.stdout)
'
  exit 0
}

# A flagged final message gets one notice plus one pending re-issue. A clean
# message clears any stale flag so a later good turn is not re-issued against.
scan_facing_or_notice() {
  local path="$1"
  if tripwire_scan_command scan-file --failure-mode closed "$path" >/dev/null; then
    exit 0
  fi
  emit_facing_notice_and_exit
}

# UserPromptSubmit: if a Tier A breach is pending, inject the rules re-issue as
# model-only additionalContext on this next request, then clear the flag.
emit_pending_reissue_if_set() {
  local flag_file
  local reissue

  flag_file="$(pending_reissue_file "$(pending_reissue_key)")" || exit 0
  if [[ ! -e "$flag_file" ]]; then
    exit 0
  fi
  rm -f "$flag_file" 2>/dev/null || true

  reissue="$(tripwire_emit_correction)"
  TRIPWIRE_REISSUE="$reissue" python3 -c '
import json
import os
import sys

reissue = os.environ["TRIPWIRE_REISSUE"]
json.dump({
    "hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit",
        "additionalContext": reissue,
    }
}, sys.stdout)
'
  exit 0
}

event="$(normalise_event "$event")"

case "$event" in
  SessionStart)
    tripwire_emit_reminder
    exit 0
    ;;
  UserPromptSubmit)
    # Always exits: emits the pending re-issue when set, otherwise exits clean.
    emit_pending_reissue_if_set
    ;;
  PreToolUse | Stop | SubagentStop)
    ;;
  "")
    exit 0
    ;;
  *)
    exit 0
    ;;
esac

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
extract_path="$work_dir/extracted.txt"

case "$event" in
  PreToolUse)
    if ! action="$(printf '%s' "$payload" | python3 "$extractor_path" pre-tool-use "$extract_path")"; then
      pretooluse_fail_closed
    fi
    case "$action" in
      pass)
        exit 0
        ;;
      scan-text)
        scan_file_or_block "$extract_path"
        ;;
      scan-bash)
        scan_bash_or_block "$extract_path"
        ;;
      *)
        pretooluse_fail_closed
        ;;
    esac
    ;;
  Stop)
    if ! action="$(printf '%s' "$payload" | python3 "$extractor_path" stop "$extract_path")"; then
      emit_facing_notice_and_exit
    fi
    case "$action" in
      scan-text)
        scan_facing_or_notice "$extract_path"
        ;;
      pass)
        exit 0
        ;;
      *)
        emit_facing_notice_and_exit
        ;;
    esac
    ;;
  SubagentStop)
    # SubagentStop mirrors Stop: agent-to-agent prose cannot be blocked before
    # the reading agent sees it, so apply the same never-block notice plus
    # pending re-issue. Only the extractor command differs, reading the
    # subagent's final text from its transcript.
    if ! action="$(printf '%s' "$payload" | python3 "$extractor_path" subagent-stop "$extract_path")"; then
      emit_facing_notice_and_exit
    fi
    case "$action" in
      scan-text)
        scan_facing_or_notice "$extract_path"
        ;;
      pass)
        exit 0
        ;;
      *)
        emit_facing_notice_and_exit
        ;;
    esac
    ;;
esac
