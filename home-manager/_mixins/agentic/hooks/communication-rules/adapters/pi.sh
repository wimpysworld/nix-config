#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "$script_dir/contract.sh"

pi_usage() {
  cat <<'EOF'
Usage: pi.sh <context|input|tool_call|message_end|tool_result> [--existing-blocked]

Reads one Pi extension event JSON payload from stdin.
EOF
}

pi_existing_blocked_args=()
for arg in "$@"; do
  case "$arg" in
    --existing-blocked)
      pi_existing_blocked_args+=("$arg")
      ;;
  esac
done

pi_extract() {
  local event_name="$1"
  local output_dir="$2"

  python3 "$script_dir/pi.py" "$event_name" "$output_dir"
}

pi_gate_file() {
  local path="$1"

  tripwire_gate scan-file "${pi_existing_blocked_args[@]}" "$path"
}

pi_gate_bash() {
  local path="$1"
  local command_text

  command_text="$(cat -- "$path")"
  tripwire_gate scan-bash "${pi_existing_blocked_args[@]}" "$command_text"
}

# Tier A facing prose: never block, never re-roll. A clean final message passes;
# a breach prints the "reissue" sentinel and exits 0. The extension turns the
# sentinel into a pending re-issue (model-only, next turn) plus a user notice.
pi_facing_gate_file() {
  local path="$1"

  if tripwire_scan_command scan-file "$path" >/dev/null; then
    tripwire_state pass
    return 0
  fi

  printf 'reissue\n'
  return 0
}

pi_gate_extraction() {
  local event_name="$1"
  local temp_dir
  local action
  local status

  temp_dir="$(mktemp -d)"

  if ! pi_extract "$event_name" "$temp_dir"; then
    if [[ "$event_name" == "message_end" ]]; then
      # Tier A surface: re-issue rather than block prose the user already saw.
      printf 'reissue\n'
    else
      tripwire_fail_closed "${pi_existing_blocked_args[@]}"
    fi
    rm -rf "$temp_dir"
    return
  fi

  action="$(cat -- "$temp_dir/action")"
  case "$action" in
    pass)
      tripwire_state pass
      status=$?
      ;;
    text)
      pi_gate_file "$temp_dir/payload"
      status=$?
      ;;
    bash)
      pi_gate_bash "$temp_dir/payload"
      status=$?
      ;;
    correction)
      pi_facing_gate_file "$temp_dir/payload"
      status=$?
      ;;
    fail)
      if [[ "$event_name" == "message_end" ]]; then
        # Tier A surface: cannot block prose the user saw. Re-issue, do not block.
        printf 'reissue\n'
        status=0
      else
        tripwire_fail_closed "${pi_existing_blocked_args[@]}"
        status=$?
      fi
      ;;
    *)
      tripwire_fail_closed "${pi_existing_blocked_args[@]}"
      status=$?
      ;;
  esac

  rm -rf "$temp_dir"
  return "$status"
}

main() {
  local event_name="${1:-}"
  shift || true

  case "$event_name" in
    context)
      tripwire_emit_reminder
      ;;
    input)
      tripwire_state pass
      ;;
    tool_call | message_end | tool_result)
      pi_gate_extraction "$event_name"
      ;;
    -h | --help | help)
      pi_usage
      ;;
    *)
      pi_usage >&2
      return 2
      ;;
  esac
}

main "$@"
