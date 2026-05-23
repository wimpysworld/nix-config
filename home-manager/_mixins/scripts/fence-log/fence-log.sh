#!/usr/bin/env bash

# Inspect Fence per-launch logs under ${XDG_STATE_HOME:-$HOME/.local/state}/fence.
#
# The fenced wrappers (claude-fenced, codex-fenced, opencode-fenced,
# pi-fenced) write one log file per launch and refresh a per-agent
# `<agent>-current.log` symlink. This script offers safe browsing without
# accepting arbitrary paths: the agent name is whitelisted and the log
# directory is fixed.

set -euo pipefail

readonly AGENTS=("claude" "codex" "opencode" "pi")
readonly LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/fence"
readonly PAGER_CMD="${PAGER:-less}"

show_help() {
	cat <<'EOF'
Usage: fence-log <agent> [command]
       fence-log --list-agents

Inspect Fence per-launch logs for fenced agents.

Agents:
  claude    Claude Code (claude-fenced)
  codex     Codex (codex-fenced)
  opencode  OpenCode (opencode-fenced)
  pi        Pi (pi-fenced)

Commands:
  current     Show the most recent launch log (default).
  tail        Follow the current log with `tail -F`.
  list        List historical logs for the agent, newest first.
  path        Print the resolved current log path and exit.

Examples:
  fence-log claude
  fence-log codex tail
  fence-log opencode list
  fence-log pi path

Logs live in $XDG_STATE_HOME/fence and are retained for 14 days by a
user-level systemd-tmpfiles rule. Files are 0600 and the directory is 0700.
EOF
}

is_known_agent() {
	local candidate="$1"
	local agent
	for agent in "${AGENTS[@]}"; do
		if [[ "$candidate" == "$agent" ]]; then
			return 0
		fi
	done
	return 1
}

ensure_log_dir() {
	if [[ ! -d "$LOG_DIR" ]]; then
		echo "fence-log: no log directory at $LOG_DIR" >&2
		echo "Run a fenced agent first (claude-fenced, codex-fenced, opencode-fenced, pi-fenced)." >&2
		exit 1
	fi
}

current_log_path() {
	local agent="$1"
	local symlink="$LOG_DIR/$agent-current.log"
	if [[ -L "$symlink" || -f "$symlink" ]]; then
		# Resolve to the real per-launch file so callers see the live target.
		readlink -f -- "$symlink"
		return 0
	fi
	return 1
}

cmd_current() {
	local agent="$1"
	local path
	if ! path="$(current_log_path "$agent")"; then
		echo "fence-log: no current log for '$agent' in $LOG_DIR" >&2
		exit 1
	fi
	if [[ ! -f "$path" ]]; then
		echo "fence-log: current symlink for '$agent' points at missing file: $path" >&2
		exit 1
	fi
	"$PAGER_CMD" -- "$path"
}

cmd_tail() {
	local agent="$1"
	# Follow the stable `<agent>-current.log` path rather than the resolved
	# per-launch target. `tail -F` retries on path changes, so when a fresh
	# fenced launch swings the symlink to a new file, this picks it up
	# instead of staying pinned to the previous launch.
	local symlink="$LOG_DIR/$agent-current.log"
	if [[ ! -L "$symlink" && ! -f "$symlink" ]]; then
		echo "fence-log: no current log for '$agent' in $LOG_DIR" >&2
		exit 1
	fi
	exec tail -F -- "$symlink"
}

cmd_list() {
	local agent="$1"
	shopt -s nullglob
	local candidates=("$LOG_DIR/$agent"-*.log)
	shopt -u nullglob
	local files=()
	local candidate
	for candidate in "${candidates[@]}"; do
		# Skip the `<agent>-current.log` symlink: only list real per-launch
		# files so historical filenames are unambiguous.
		if [[ -L "$candidate" ]]; then
			continue
		fi
		files+=("$candidate")
	done
	if ((${#files[@]} == 0)); then
		echo "fence-log: no historical logs for '$agent' in $LOG_DIR" >&2
		exit 1
	fi
	# Newest first; the timestamp is embedded in the filename so lexical
	# sort is stable.
	printf '%s\n' "${files[@]}" | sort -r
}

cmd_path() {
	local agent="$1"
	local path
	if ! path="$(current_log_path "$agent")"; then
		echo "fence-log: no current log for '$agent' in $LOG_DIR" >&2
		exit 1
	fi
	printf '%s\n' "$path"
}

main() {
	if (($# == 0)) || [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
		show_help
		exit 0
	fi

	if [[ "$1" == "--list-agents" ]]; then
		printf '%s\n' "${AGENTS[@]}"
		exit 0
	fi

	local agent="$1"
	shift || true

	if ! is_known_agent "$agent"; then
		echo "fence-log: unknown agent '$agent'" >&2
		echo "Known agents: ${AGENTS[*]}" >&2
		exit 2
	fi

	ensure_log_dir

	local subcommand="${1:-current}"
	case "$subcommand" in
	current) cmd_current "$agent" ;;
	tail) cmd_tail "$agent" ;;
	list) cmd_list "$agent" ;;
	path) cmd_path "$agent" ;;
	*)
		echo "fence-log: unknown command '$subcommand'" >&2
		echo "Run 'fence-log --help' for usage." >&2
		exit 2
		;;
	esac
}

main "$@"
