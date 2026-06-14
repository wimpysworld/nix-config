#!/usr/bin/env bash
set -euo pipefail

fixture_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$fixture_dir/../.." && pwd)"
adapter="$root_dir/adapters/pi.sh"
rules="$root_dir/communication-rules.md"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

scanner="$tmp_dir/agent-communication-check"
cat > "$scanner" <<EOF
#!/usr/bin/env bash
exec python3 "$root_dir/scanner.py" --rules "$rules" "\$@"
EOF
chmod +x "$scanner"

fail() {
  printf 'pi fixture failed: %s\n' "$1" >&2
  exit 1
}

run_adapter() {
  local event_name="$1"
  local fixture="$2"
  local fixture_path
  shift 2

  case "$fixture" in
    /*)
      fixture_path="$fixture"
      ;;
    *)
      fixture_path="$fixture_dir/$fixture"
      ;;
  esac

  TRIPWIRE_SCANNER="$scanner" bash "$adapter" "$event_name" "$@" < "$fixture_path"
}

expect_pass() {
  local event_name="$1"
  local fixture="$2"
  local output

  output="$(run_adapter "$event_name" "$fixture")" || fail "$fixture did not pass"
  [[ "$output" == "pass" ]] || fail "$fixture expected pass, got: $output"
}

expect_reminder() {
  local event_name="$1"
  local fixture="$2"
  local output

  output="$(run_adapter "$event_name" "$fixture")" || fail "$fixture did not remind"
  [[ "$output" == Reminder:* ]] || fail "$fixture did not print reminder"
}

expect_block() {
  local event_name="$1"
  local fixture="$2"
  local output
  local status

  set +e
  output="$(run_adapter "$event_name" "$fixture")"
  status=$?
  set -e

  [[ "$status" -eq 1 ]] || fail "$fixture expected block status, got $status"
  [[ "$output" == Blocked.* ]] || fail "$fixture did not print block message"
  [[ "$(tail -n 1 <<<"$output")" == "block" ]] || fail "$fixture did not end with block state"
  [[ "$output" != *DELVE* ]] || fail "$fixture exposed payload text"
}

# Tier A facing prose: a message_end breach never blocks. The adapter prints the
# "reissue" sentinel and exits 0. The extension turns it into a pending re-issue
# plus a user notice; the adapter never leaks the scanned payload text.
expect_reissue() {
  local event_name="$1"
  local fixture="$2"
  local output
  local status
  local leak
  leak="DEL""VE"

  set +e
  output="$(run_adapter "$event_name" "$fixture")"
  status=$?
  set -e

  [[ "$status" -eq 0 ]] || fail "$fixture expected reissue exit 0, got $status"
  [[ "$output" == "reissue" ]] || fail "$fixture expected reissue sentinel, got: $output"
  [[ "$output" != *"$leak"* ]] || fail "$fixture exposed payload text"
}

expect_duplicate_block() {
  local output
  local status

  set +e
  output="$(run_adapter tool_call tool-call-write-blocked.json --existing-blocked)"
  status=$?
  set -e

  [[ "$status" -eq 1 ]] || fail "duplicate block expected status 1, got $status"
  [[ "$output" == "block" ]] || fail "duplicate block should emit only state"
}

expect_disclosure_pass() {
  local payload_file="$tmp_dir/policy-disclosure.json"
  local output

  python3 - "$rules" "$payload_file" <<'PY'
import json
import sys
from pathlib import Path

rules = Path(sys.argv[1]).read_text(encoding="utf-8").strip()
Path(sys.argv[2]).write_text(json.dumps({
    "message": {
        "role": "assistant",
        "content": [{"type": "text", "text": rules}],
    },
}), encoding="utf-8")
PY

  output="$(run_adapter message_end "$payload_file")" || fail "policy disclosure did not pass"
  [[ "$output" == "pass" ]] || fail "policy disclosure expected pass, got: $output"
}

expect_reminder context context.json
expect_pass input input.json

expect_pass tool_call tool-call-write-clean.json
expect_pass tool_call tool-call-bash-stdout-pass.json
expect_pass message_end message-end-final-clean.json
expect_disclosure_pass
expect_pass message_end message-end-tool-use-pass.json
expect_pass tool_result tool-result-subagent-clean.json
expect_pass tool_result tool-result-other-tool-pass.json

expect_block tool_call tool-call-write-blocked.json
expect_block tool_call tool-call-patch-blocked.json
expect_block tool_call tool-call-mcp-post-blocked.json
expect_block tool_call tool-call-bash-post-blocked.json
expect_block tool_call tool-call-gh-unresolvable-body-fails-closed.json
expect_block tool_call tool-call-write-missing-content-fails-closed.json
expect_reissue message_end message-end-extraction-failure.json
expect_block tool_result tool-result-subagent-blocked.json
expect_block tool_result tool-result-subagent-missing-content-fails-closed.json

expect_reissue message_end message-end-final-blocked.json
expect_duplicate_block

tsx "$fixture_dir/run-extension-fixtures.ts"

printf 'pi fixtures passed\n'
