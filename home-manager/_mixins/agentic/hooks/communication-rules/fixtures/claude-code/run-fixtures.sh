#!/usr/bin/env bash
set -euo pipefail

fixture_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd -- "$fixture_dir/../.." && pwd)"
adapter="$root_dir/adapters/claude-code.sh"
scanner="$root_dir/scanner.py"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

scanner_wrapper="$tmp_dir/agent-communication-check"
cat > "$scanner_wrapper" <<EOF
#!/usr/bin/env bash
exec python3 "$scanner" --rules "$root_dir/communication-rules.md" "\$@"
EOF
chmod +x "$scanner_wrapper"

export TRIPWIRE_SCANNER="$scanner_wrapper"
export TRIPWIRE_CLAUDE_CODE_STRIKE_DIR="$tmp_dir/pretooluse-strikes"
export TRIPWIRE_CLAUDE_CODE_REISSUE_DIR="$tmp_dir/pending-reissue"

correction_prompt="$tmp_dir/correction-prompt.md"
cat > "$correction_prompt" <<'EOF'
Revise the previous response to follow the Communication Rules. Return only the corrected response.

Communication Rules:
Use short sentences.
EOF
export TRIPWIRE_CORRECTION_PROMPT="$correction_prompt"

materialise_payload() {
  local fixture="$1"
  local payload
  payload="$(<"$fixture_dir/$fixture")"
  printf '%s' "${payload//__TRANSCRIPT_DIR__/$fixture_dir}"
}

run_case() {
  local name="$1"
  local event="$2"
  local expected_exit="$3"
  local expected_stdout="$4"
  local expected_stderr="$5"
  local payload
  local stdout_file="$tmp_dir/$name.stdout"
  local stderr_file="$tmp_dir/$name.stderr"
  local status

  payload="$(materialise_payload "$name")"
  set +e
  printf '%s' "$payload" | "$adapter" "$event" >"$stdout_file" 2>"$stderr_file"
  status=$?
  set -e

  if [[ "$status" -ne "$expected_exit" ]]; then
    printf '%s: expected exit %s, got %s\n' "$name" "$expected_exit" "$status" >&2
    return 1
  fi

  case "$expected_stdout" in
    empty)
      if [[ -s "$stdout_file" ]]; then
        printf '%s: expected empty stdout\n' "$name" >&2
        return 1
      fi
      ;;
    reminder)
      if ! grep -q '^Reminder: Follow the Communication Rules' "$stdout_file"; then
        printf '%s: expected reminder stdout\n' "$name" >&2
        return 1
      fi
      ;;
    pretooluse-deny)
      if ! assert_pretooluse "$stdout_file" deny '^Blocked\. Revise this prose'; then
        printf '%s: expected PreToolUse deny JSON\n' "$name" >&2
        return 1
      fi
      ;;
    pretooluse-yield)
      if ! assert_pretooluse "$stdout_file" allow '^Communication Rules unmet after retries, output allowed\.$'; then
        printf '%s: expected PreToolUse allow yield JSON\n' "$name" >&2
        return 1
      fi
      ;;
    pretooluse-external-yield)
      # Sub-tier B2 yield: allow decision with an operator-visible notice that
      # names the tool and target so the breach can be retracted fast.
      if ! assert_pretooluse "$stdout_file" allow '^Rules breach posted: mcp__github__add_issue_comment 42$'; then
        printf '%s: expected PreToolUse B2 external yield JSON\n' "$name" >&2
        return 1
      fi
      ;;
    pretooluse-external-yield-bash)
      # Sub-tier B2 yield for a gh post run through the Bash tool: the notice
      # names the gh subcommand so the breach can be retracted fast.
      if ! assert_pretooluse "$stdout_file" allow '^Rules breach posted: gh pr comment$'; then
        printf '%s: expected PreToolUse B2 gh-via-Bash yield JSON\n' "$name" >&2
        return 1
      fi
      ;;
    facing-notice)
      if ! assert_facing_notice "$stdout_file" '^Communication Rules breach seen, correcting next reply\.$'; then
        printf '%s: expected facing notice JSON\n' "$name" >&2
        return 1
      fi
      ;;
    reissue)
      if ! assert_reissue "$stdout_file" '^Revise the previous response.*Communication Rules:.*Use short sentences\.'; then
        printf '%s: expected UserPromptSubmit re-issue JSON\n' "$name" >&2
        return 1
      fi
      ;;
  esac

  case "$expected_stderr" in
    empty)
      if [[ -s "$stderr_file" ]]; then
        printf '%s: expected empty stderr\n' "$name" >&2
        return 1
      fi
      ;;
  esac
}

# Assert a PreToolUse hookSpecificOutput object: the permissionDecision matches
# and the permissionDecisionReason matches a regex. No top-level decision.
assert_pretooluse() {
  local stdout_file="$1"
  local decision="$2"
  local reason_regex="$3"
  python3 - "$stdout_file" "$decision" "$reason_regex" <<'PY'
import json
import re
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

if "decision" in payload:
    sys.exit(1)

specific = payload.get("hookSpecificOutput", {})
if specific.get("hookEventName") != "PreToolUse":
    sys.exit(1)
if specific.get("permissionDecision") != sys.argv[2]:
    sys.exit(1)

reason = specific.get("permissionDecisionReason", "")
sys.exit(0 if re.search(sys.argv[3], reason, re.MULTILINE) else 1)
PY
}

# Assert a Tier A facing notice: a lone systemMessage matching a regex, with no
# "decision"/"reason"/"hookSpecificOutput", so the turn ends without a re-roll.
assert_facing_notice() {
  local stdout_file="$1"
  local message_regex="$2"
  python3 - "$stdout_file" "$message_regex" <<'PY'
import json
import re
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

if "decision" in payload or "reason" in payload or "hookSpecificOutput" in payload:
    sys.exit(1)

message = payload.get("systemMessage", "")
sys.exit(0 if re.search(sys.argv[2], message, re.MULTILINE) else 1)
PY
}

# Assert a UserPromptSubmit re-issue: hookSpecificOutput.additionalContext
# matching a regex, model-only, with no decision.
assert_reissue() {
  local stdout_file="$1"
  local context_regex="$2"
  python3 - "$stdout_file" "$context_regex" <<'PY'
import json
import re
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

specific = payload.get("hookSpecificOutput", {})
if specific.get("hookEventName") != "UserPromptSubmit":
    sys.exit(1)

context = specific.get("additionalContext", "")
sys.exit(0 if re.search(sys.argv[2], context, re.MULTILINE | re.DOTALL) else 1)
PY
}

run_existing_block_case() {
  local stdout_file="$tmp_dir/duplicate.stdout"
  local stderr_file="$tmp_dir/duplicate.stderr"
  local status
  local payload

  payload="$(materialise_payload pre-tool-use-write-block.json)"
  set +e
  printf '%s' "$payload" | TRIPWIRE_EXISTING_BLOCKED=1 "$adapter" PreToolUse >"$stdout_file" 2>"$stderr_file"
  status=$?
  set -e

  if [[ "$status" -ne 0 ]]; then
    printf 'duplicate-block: expected exit 0, got %s\n' "$status" >&2
    return 1
  fi
  if [[ -s "$stdout_file" || -s "$stderr_file" ]]; then
    printf 'duplicate-block: expected no adapter output\n' >&2
    return 1
  fi
}

run_existing_stop_block_case() {
  local stdout_file="$tmp_dir/duplicate-stop.stdout"
  local stderr_file="$tmp_dir/duplicate-stop.stderr"
  local status
  local payload

  payload="$(materialise_payload stop-transcript-block.json)"
  set +e
  printf '%s' "$payload" | TRIPWIRE_EXISTING_BLOCKED=1 "$adapter" Stop >"$stdout_file" 2>"$stderr_file"
  status=$?
  set -e

  if [[ "$status" -ne 0 ]]; then
    printf 'duplicate-stop-block: expected exit 0, got %s\n' "$status" >&2
    return 1
  fi
  if [[ -s "$stdout_file" || -s "$stderr_file" ]]; then
    printf 'duplicate-stop-block: expected no adapter output\n' >&2
    return 1
  fi
}

run_disclosure_stop_case() {
  local stdout_file="$tmp_dir/disclosure.stdout"
  local stderr_file="$tmp_dir/disclosure.stderr"
  local status
  local payload

  payload="$(python3 - "$root_dir/communication-rules.md" <<'PY'
import json
import sys
from pathlib import Path

rules = Path(sys.argv[1]).read_text(encoding="utf-8").strip()
print(json.dumps({
    "hook_event_name": "Stop",
    "session_id": "session-disclosure",
    "transcript_path": "/tmp/claude-transcript.jsonl",
    "cwd": "/tmp",
    "last_assistant_message": rules,
}))
PY
)"

  set +e
  printf '%s' "$payload" | "$adapter" Stop >"$stdout_file" 2>"$stderr_file"
  status=$?
  set -e

  if [[ "$status" -ne 0 ]]; then
    printf 'disclosure-stop: expected exit 0, got %s\n' "$status" >&2
    return 1
  fi
  if [[ -s "$stdout_file" || -s "$stderr_file" ]]; then
    printf 'disclosure-stop: expected no adapter output\n' >&2
    return 1
  fi
}

# Tier A: a breaching Stop sets the pending re-issue flag, then the next
# UserPromptSubmit emits the model-only re-issue and clears the flag. Assert the
# flag file appears after the Stop and is gone after the UserPromptSubmit.
run_pending_reissue_flow() {
  local reissue_dir="$TRIPWIRE_CLAUDE_CODE_REISSUE_DIR"
  local before
  local after

  rm -rf "$reissue_dir"
  run_case stop-transcript-block.json Stop 0 facing-notice empty || return 1
  before="$(find "$reissue_dir" -type f 2>/dev/null | wc -l)"
  if [[ "$before" -ne 1 ]]; then
    printf 'pending-reissue: expected flag set after Stop, found %s\n' "$before" >&2
    return 1
  fi

  run_case user-prompt-submit.json UserPromptSubmit 0 reissue empty || return 1
  after="$(find "$reissue_dir" -type f 2>/dev/null | wc -l)"
  if [[ "$after" -ne 0 ]]; then
    printf 'pending-reissue: expected flag cleared after UserPromptSubmit, found %s\n' "$after" >&2
    return 1
  fi
}

# Reset every PreToolUse strike counter so groups below do not interfere. The
# write fixtures share one session+tool+target key, so they share a counter.
reset_strikes() {
  rm -rf "$TRIPWIRE_CLAUDE_CODE_STRIKE_DIR"
}

run_case session-start.json SessionStart 0 reminder empty
run_case user-prompt-submit.json UserPromptSubmit 0 empty empty

reset_strikes
run_case pre-tool-use-write-pass.json PreToolUse 0 empty empty
# Tier B world output: strikes 1 and 2 deny, strike 3 yields. The strike key is
# per session+tool+target, so repeating the same fixture walks the cap.
reset_strikes
run_case pre-tool-use-write-block.json PreToolUse 0 pretooluse-deny empty
run_case pre-tool-use-write-block.json PreToolUse 0 pretooluse-deny empty
run_case pre-tool-use-write-block.json PreToolUse 0 pretooluse-yield empty
# B1 stable-key regression: a model that REVISES the body between retries must
# still walk the cap. Three different breaching bodies write to the SAME
# file_path and session, so the stable session+tool+path key counts them as
# strikes 1, 2 and 3 and the third yields. A per-body key would never yield.
reset_strikes
run_case pre-tool-use-write-vary-1-block.json PreToolUse 0 pretooluse-deny empty
run_case pre-tool-use-write-vary-2-block.json PreToolUse 0 pretooluse-deny empty
run_case pre-tool-use-write-vary-3-block.json PreToolUse 0 pretooluse-yield empty
# A clean pass on the same key resets the counter, so the next varying breach
# starts again at deny.
reset_strikes
run_case pre-tool-use-write-vary-1-block.json PreToolUse 0 pretooluse-deny empty
run_case pre-tool-use-write-pass.json PreToolUse 0 empty empty
run_case pre-tool-use-write-vary-2-block.json PreToolUse 0 pretooluse-deny empty
reset_strikes
run_case pre-tool-use-write-extraction-failure.json PreToolUse 0 pretooluse-deny empty
reset_strikes
run_case pre-tool-use-edit-pass.json PreToolUse 0 empty empty
run_case pre-tool-use-edit-block.json PreToolUse 0 pretooluse-deny empty
reset_strikes
run_case pre-tool-use-bash-pass.json PreToolUse 0 empty empty
run_case pre-tool-use-bash-block.json PreToolUse 0 pretooluse-deny empty
reset_strikes
run_case pre-tool-use-mcp-post-pass.json PreToolUse 0 empty empty
run_case pre-tool-use-mcp-post-block.json PreToolUse 0 pretooluse-deny empty
# A clean pass on the same target resets that target's strike counter, so the
# next breach starts again at strike 1 (deny), never at the yield.
reset_strikes
run_case pre-tool-use-write-block.json PreToolUse 0 pretooluse-deny empty
run_case pre-tool-use-write-block.json PreToolUse 0 pretooluse-deny empty
run_case pre-tool-use-write-pass.json PreToolUse 0 empty empty
run_case pre-tool-use-write-block.json PreToolUse 0 pretooluse-deny empty

# Sub-tier B2 external posts: irretractable once they yield, so five strikes.
# Deny on strikes 1-4, yield on strike 5 with the operator-visible notice naming
# the tool and target. The strike key is the stable session+tool identity, so
# repeating the same fixture walks the wider cap.
reset_strikes
run_case pre-tool-use-mcp-post-target-block.json PreToolUse 0 pretooluse-deny empty
run_case pre-tool-use-mcp-post-target-block.json PreToolUse 0 pretooluse-deny empty
run_case pre-tool-use-mcp-post-target-block.json PreToolUse 0 pretooluse-deny empty
run_case pre-tool-use-mcp-post-target-block.json PreToolUse 0 pretooluse-deny empty
run_case pre-tool-use-mcp-post-target-block.json PreToolUse 0 pretooluse-external-yield empty
# The stable key means reworded post bodies (same session+tool, different body)
# share one budget: two distinct breaching bodies count as strikes 1 and 2, not
# two fresh strike-1 actions. A clean post on the same session+tool then resets
# the counter, so the next breach starts again at deny.
reset_strikes
run_case pre-tool-use-mcp-post-block.json PreToolUse 0 pretooluse-deny empty
run_case pre-tool-use-mcp-post-block-reworded.json PreToolUse 0 pretooluse-deny empty
run_case pre-tool-use-mcp-post-pass.json PreToolUse 0 empty empty
run_case pre-tool-use-mcp-post-block.json PreToolUse 0 pretooluse-deny empty

# Sub-tier B2 gh-via-Bash: a gh post run through the Bash tool is external, so it
# walks the five-strike cap (deny 1-4, yield 5) with a notice naming the gh
# subcommand, not the three-strike local cap.
reset_strikes
run_case pre-tool-use-bash-gh-post-target-block.json PreToolUse 0 pretooluse-deny empty
run_case pre-tool-use-bash-gh-post-target-block.json PreToolUse 0 pretooluse-deny empty
run_case pre-tool-use-bash-gh-post-target-block.json PreToolUse 0 pretooluse-deny empty
run_case pre-tool-use-bash-gh-post-target-block.json PreToolUse 0 pretooluse-deny empty
run_case pre-tool-use-bash-gh-post-target-block.json PreToolUse 0 pretooluse-external-yield-bash empty

run_case stop-transcript-pass.json Stop 0 empty empty
run_disclosure_stop_case
# Tier A facing prose: never block, never re-roll. A breach emits a short notice.
run_case stop-transcript-block.json Stop 0 facing-notice empty
run_pending_reissue_flow
run_case stop-transcript-extraction-failure.json Stop 0 facing-notice empty
run_existing_block_case
run_existing_stop_block_case

# SubagentStop mirrors the Stop facing path: clean pass, breach notice, no block.
run_case subagent-stop-pass.json SubagentStop 0 empty empty
run_case subagent-stop-block.json SubagentStop 0 facing-notice empty

printf 'claude-code fixtures passed: 46\n'
