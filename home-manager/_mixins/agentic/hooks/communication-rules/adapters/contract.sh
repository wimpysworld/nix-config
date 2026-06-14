tripwire_scanner="${TRIPWIRE_SCANNER:-agent-communication-check}"
tripwire_correction_prompt="${TRIPWIRE_CORRECTION_PROMPT:-}"

tripwire_usage() {
  cat <<'EOF'
Usage: agent-communication-adapter <command> [args]

Commands:
  state pass|block|extraction-failed
  scan-text [--failure-mode open|closed] [text...]
  scan-file [--failure-mode open|closed] <path>
  scan-bash [--failure-mode open|closed] [command...]
  gate-text [--existing-blocked] [text...]
  gate-file [--existing-blocked] <path>
  gate-bash [--existing-blocked] [command...]
  fail-closed [--existing-blocked]
  emit-block [--existing-blocked]
  remind
  correction
EOF
}

tripwire_existing_blocked() {
  case "${TRIPWIRE_EXISTING_BLOCKED:-0}" in
    1 | true | yes)
      return 0
      ;;
  esac

  for arg in "$@"; do
    if [[ "$arg" == "--existing-blocked" ]]; then
      return 0
    fi
  done

  return 1
}

tripwire_state() {
  case "${1:-}" in
    pass)
      printf 'pass\n'
      return 0
      ;;
    block | extraction-failed)
      printf 'block\n'
      return 1
      ;;
    *)
      printf 'usage: state pass|block|extraction-failed\n' >&2
      return 2
      ;;
  esac
}

tripwire_emit_fallback_block() {
  cat <<'EOF'
Blocked. Revise this prose to follow the Communication Rules.
EOF
}

tripwire_emit_block_once() {
  if tripwire_existing_blocked "$@"; then
    return 0
  fi

  if [[ "${TRIPWIRE_BLOCK_EMITTED:-0}" == "1" ]]; then
    return 0
  fi

  export TRIPWIRE_BLOCK_EMITTED=1
  if ! "$tripwire_scanner" block-message 2>/dev/null; then
    tripwire_emit_fallback_block
  fi
}

tripwire_emit_reminder() {
  "$tripwire_scanner" remind 2>/dev/null || true
}

tripwire_emit_correction() {
  if [[ -n "$tripwire_correction_prompt" && -r "$tripwire_correction_prompt" ]]; then
    cat -- "$tripwire_correction_prompt"
    return 0
  fi

  cat <<'EOF'
Revise the previous response to follow the Communication Rules. Return only the corrected response.
EOF
}

tripwire_failure_mode="closed"

tripwire_parse_failure_mode() {
  tripwire_failure_mode="closed"
  if [[ "${1:-}" == "--failure-mode" ]]; then
    if [[ "${2:-}" != "open" && "${2:-}" != "closed" ]]; then
      printf 'usage: --failure-mode open|closed\n' >&2
      return 2
    fi
    tripwire_failure_mode="$2"
    shift 2
  fi
  tripwire_remaining_args=("$@")
}

tripwire_scan() {
  local mode="$1"
  local scanner_output
  local scanner_status
  shift

  if scanner_output="$("$tripwire_scanner" "$mode" --format plain "$@" 2>/dev/null)"; then
    scanner_status=0
  else
    scanner_status=$?
  fi

  case "$scanner_output" in
    pass)
      tripwire_state pass
      return 0
      ;;
    block)
      tripwire_state block
      return 1
      ;;
  esac

  if [[ "$scanner_status" -eq 0 ]]; then
    tripwire_state pass
    return 0
  fi

  if [[ "$tripwire_failure_mode" == "open" ]]; then
    tripwire_state pass
    return 0
  fi

  tripwire_state extraction-failed
}

tripwire_scan_command() {
  local mode="$1"
  shift
  tripwire_parse_failure_mode "$@"
  tripwire_scan "$mode" "${tripwire_remaining_args[@]}"
}

tripwire_gate() {
  local mode="$1"
  local existing_blocked_args=()
  local scan_args=()
  local arg
  shift

  for arg in "$@"; do
    if [[ "$arg" == "--existing-blocked" ]]; then
      existing_blocked_args+=("$arg")
    else
      scan_args+=("$arg")
    fi
  done

  if tripwire_scan_command "$mode" "${scan_args[@]}" >/dev/null; then
    tripwire_state pass
    return 0
  fi

  tripwire_emit_block_once "${existing_blocked_args[@]}"
  tripwire_state block
}

tripwire_fail_closed() {
  tripwire_emit_block_once "$@"
  tripwire_state extraction-failed
}

tripwire_adapter_main() {
  local command="${1:-}"
  shift || true

  case "$command" in
    state)
      tripwire_state "$@"
      ;;
    scan-text)
      tripwire_scan_command scan-text "$@"
      ;;
    scan-file)
      tripwire_scan_command scan-file "$@"
      ;;
    scan-bash)
      tripwire_scan_command scan-bash "$@"
      ;;
    gate-text)
      tripwire_gate scan-text "$@"
      ;;
    gate-file)
      tripwire_gate scan-file "$@"
      ;;
    gate-bash)
      tripwire_gate scan-bash "$@"
      ;;
    fail-closed)
      tripwire_fail_closed "$@"
      ;;
    emit-block)
      tripwire_emit_block_once "$@"
      ;;
    remind)
      tripwire_emit_reminder
      ;;
    correction)
      tripwire_emit_correction
      ;;
    -h | --help | help)
      tripwire_usage
      ;;
    *)
      tripwire_usage >&2
      return 2
      ;;
  esac
}
