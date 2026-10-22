#!/usr/bin/env bash

usage() {
	echo "Usage: agent-purge [--force]"
	echo ""
	echo "Remove the chat history, caches, logs and temporary files of Claude Code,"
	echo "Codex, Pi and OpenCode, plus the shared agent temporary files and review"
	echo "reports. Prints a summary and asks before it deletes anything."
	echo ""
	echo "Options:"
	echo "  --force     Run even when a coding-agent process is running."
	echo "  -h, --help  Show this help."
}

force=false

while [[ $# -gt 0 ]]; do
	case "${1}" in
		--force)
			force=true
			;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			echo "ERROR: Unknown argument: ${1}" >&2
			usage >&2
			exit 1
			;;
	esac
	shift
done

# Fence exports FENCE_SANDBOX=1 and the repository wrappers export
# NOUGHTY_AGENT_ISOLATION=Fenced. Inside the sandbox /tmp is a private tmpfs
# and the host processes are invisible, so neither check below would be honest.
if [[ "${FENCE_SANDBOX:-0}" == 1 || "${NOUGHTY_AGENT_ISOLATION:-}" == Fenced ]]; then
	echo "ERROR: agent-purge cannot run inside the Fence sandbox." >&2
	echo "The sandbox hides the host /tmp and the host processes. Run it from a host shell." >&2
	exit 1
fi

uid=$(id -u)

# These are the process names that the packaged clients run under. Nix
# wrappers rename the Claude Code and OpenCode binaries, and the kernel
# truncates process names to 15 characters. Pi runs as node with the
# pi-coding-agent bundle as its script, so it is matched by command line.
client_processes=$(
	{
		pgrep -a -u "${uid}" -x 'claude|\.claude-wrapped|codex|codex-code-mode|opencode|\.opencode-wrapp|pi' || true
		pgrep -a -u "${uid}" -f 'pi-coding-agent/dist/' || true
	} | sort -u -n
)
if [[ -n "${client_processes}" ]]; then
	if "${force}"; then
		echo "WARNING: coding-agent processes are running; continuing because of --force." >&2
	else
		echo "ERROR: coding-agent processes are running. Quit them first, or pass --force:" >&2
		echo "${client_processes}" >&2
		exit 1
	fi
fi

shopt -s nullglob dotglob

home_dir="${HOME}"
config_home="${XDG_CONFIG_HOME:-${home_dir}/.config}"
data_home="${XDG_DATA_HOME:-${home_dir}/.local/share}"
state_home="${XDG_STATE_HOME:-${home_dir}/.local/state}"
cache_home="${XDG_CACHE_HOME:-${home_dir}/.cache}"
fence_share="${cache_home}/fence-share"
# AGENT_PURGE_TMP_ROOT exists for testing only, so a test can stand in for /tmp.
tmp_root="${AGENT_PURGE_TMP_ROOT:-/tmp}"

claude_dir="${home_dir}/.claude"
pi_dir="${home_dir}/.pi/agent"
opencode_data="${data_home}/opencode"

groups=("Claude Code" "Codex" "Pi" "OpenCode" "Shared temporary files" "Review reports")
target_paths=()
target_groups=()

# Record a target when it exists. A symlink target is recorded as the link
# itself, and rm never follows it.
add() {
	local group="${1}"
	shift
	local path
	for path in "$@"; do
		if [[ -e "${path}" || -L "${path}" ]]; then
			target_paths+=("${path}")
			target_groups+=("${group}")
		fi
	done
}

# Record a /tmp target only when the user owns it, because /tmp is shared
# with other users.
add_owned() {
	local group="${1}"
	shift
	local path
	for path in "$@"; do
		if [[ -O "${path}" && ! -L "${path}" ]]; then
			add "${group}" "${path}"
		fi
	done
}

# Claude Code. Each project directory holds session transcripts
# (<session>.jsonl) and per-session directories named by the session UUID,
# which hold subagents/, tool-results/ and workflows/. Only those are
# selected, so memory/ is never a target.
uuid_re='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
claude_projects=()
for project in "${claude_dir}/projects"/*/; do
	project="${project%/}"
	[[ -L "${project}" ]] && continue
	claude_projects+=("${project}")
	add "Claude Code" "${project}"/*.jsonl* "${project}/sessions-index.json"
	for entry in "${project}"/*/; do
		entry="${entry%/}"
		if [[ ! -L "${entry}" && "$(basename "${entry}")" =~ ${uuid_re} ]]; then
			add "Claude Code" "${entry}"
		fi
	done
done
add "Claude Code" \
	"${claude_dir}/history.jsonl" \
	"${claude_dir}/file-history" \
	"${claude_dir}/paste-cache" \
	"${claude_dir}/image-cache" \
	"${claude_dir}/shell-snapshots" \
	"${claude_dir}/session-env" \
	"${claude_dir}/tasks" \
	"${claude_dir}/teams" \
	"${claude_dir}/todos" \
	"${claude_dir}/plans" \
	"${claude_dir}/debug" \
	"${claude_dir}/logs" \
	"${claude_dir}/statsig" \
	"${claude_dir}/uploads" \
	"${claude_dir}/dev-mods" \
	"${claude_dir}/usage-data" \
	"${claude_dir}/feedback-bundles" \
	"${claude_dir}/feedback/drafts" \
	"${claude_dir}/cache" \
	"${claude_dir}/stats-cache.json" \
	"${claude_dir}/backups" \
	"${home_dir}"/.claude.json.backup.* \
	"${cache_home}/claude-cli-nodejs" \
	"${fence_share}/claude-${uid}"
add_owned "Claude Code" "${tmp_root}/claude-${uid}" "${tmp_root}"/claude-mcp-config.*.json

# Codex. The repository seeds both ~/.codex and ~/.config/codex, so both are
# covered. A root that resolves to one already seen is skipped.
seen_codex=()
for codex_dir in "${home_dir}/.codex" "${config_home}/codex"; do
	[[ -d "${codex_dir}" ]] || continue
	resolved=$(realpath -- "${codex_dir}")
	for seen in "${seen_codex[@]}"; do
		[[ "${seen}" == "${resolved}" ]] && continue 2
	done
	seen_codex+=("${resolved}")
	add "Codex" \
		"${codex_dir}/history.jsonl" \
		"${codex_dir}/session_index.jsonl" \
		"${codex_dir}/sessions" \
		"${codex_dir}/archived_sessions" \
		"${codex_dir}"/thread_history_1.sqlite* \
		"${codex_dir}"/state_5.sqlite* \
		"${codex_dir}"/logs_2.sqlite* \
		"${codex_dir}/log" \
		"${codex_dir}/shell_snapshots" \
		"${codex_dir}/.tmp" \
		"${codex_dir}/tmp" \
		"${codex_dir}/cache" \
		"${codex_dir}/plugins/cache" \
		"${codex_dir}/models_cache.json" \
		"${codex_dir}/cloud-config-bundle-cache.json" \
		"${codex_dir}/cloud-requirements-cache.json"
done

# Pi.
add "Pi" \
	"${pi_dir}/sessions" \
	"${pi_dir}/run-history.jsonl" \
	"${pi_dir}/mcp-cache.json" \
	"${pi_dir}/cache" \
	"${pi_dir}/pi-debug.log" \
	"${pi_dir}/crashes.json" \
	"${pi_dir}/mcp.log" \
	"${pi_dir}/tmp"

# OpenCode. Sessions live in opencode.db, which also holds credentials, so
# the database file is never a target. The CLI lists the root sessions with
# a read-only query and deletes each one, together with its child sessions.
# `opencode session list` only covers the project of the working directory,
# which is why the query is used to list them.
opencode_sessions=()
opencode_note=""
if [[ -e "${opencode_data}/opencode.db" ]]; then
	if command -v opencode >/dev/null 2>&1; then
		if session_rows=$(cd "${home_dir}" && opencode db --pure --format tsv 'SELECT id FROM session WHERE parent_id IS NULL' 2>/dev/null); then
			while IFS= read -r row; do
				[[ "${row}" == ses_* ]] && opencode_sessions+=("${row}")
			done <<<"${session_rows}"
		else
			opencode_note="the OpenCode CLI could not list sessions, so they are kept"
		fi
	else
		opencode_note="opencode is not on PATH, so its sessions are kept"
	fi
fi
add "OpenCode" \
	"${opencode_data}/snapshot" \
	"${opencode_data}/log" \
	"${opencode_data}/storage" \
	"${state_home}/opencode/prompt-history.jsonl"

# Shared temporary files. Fenced agents use fence-share as TMPDIR; unfenced
# agents use /tmp.
add "Shared temporary files" \
	"${fence_share}"/tmp.* \
	"${fence_share}/agent-plans" \
	"${fence_share}/agent-research"
add_owned "Shared temporary files" \
	"${tmp_root}/agent-plans" \
	"${tmp_root}/agent-research" \
	"${tmp_root}/agent-communication-rules" \
	"${tmp_root}"/fence-wayland-runtime.* \
	"${tmp_root}"/fence-chromium.*

add "Review reports" "${state_home}/agent-reviews"

count_files() {
	if [[ $# -eq 0 ]]; then
		echo 0
		return
	fi
	find "$@" \( -type f -o -type l \) -printf '.' 2>/dev/null | wc -c
}

total_bytes() {
	if [[ $# -eq 0 ]]; then
		echo 0
		return
	fi
	du -s -c -B1 -- "$@" 2>/dev/null | tail -n 1 | cut -f 1
}

human() {
	numfmt --to=iec --suffix=B "${1}"
}

if [[ ${#target_paths[@]} -eq 0 && ${#opencode_sessions[@]} -eq 0 ]]; then
	echo "Nothing to remove."
	[[ -n "${opencode_note}" ]] && echo "Note: ${opencode_note}."
	exit 0
fi

echo "agent-purge will remove:"
for group in "${groups[@]}"; do
	paths=()
	for i in "${!target_paths[@]}"; do
		[[ "${target_groups[i]}" == "${group}" ]] && paths+=("${target_paths[i]}")
	done
	line=$(printf '  %-24s %8s files  %8s' "${group}" "$(count_files "${paths[@]}")" "$(human "$(total_bytes "${paths[@]}")")")
	if [[ "${group}" == OpenCode ]]; then
		line+="  plus ${#opencode_sessions[@]} sessions"
	fi
	echo "${line}"
done
printf '  %-24s %8s files  %8s\n' "Total" "$(count_files "${target_paths[@]}")" "$(human "$(total_bytes "${target_paths[@]}")")"
[[ -n "${opencode_note}" ]] && echo "Note: ${opencode_note}."
echo ""

printf 'Remove these files? [y/N] '
answer=""
if ! read -r answer; then
	echo ""
	echo "No answer; nothing removed."
	exit 1
fi
case "${answer,,}" in
	y | yes) ;;
	*)
		echo "Nothing removed."
		exit 0
		;;
esac

failed=0
for session in "${opencode_sessions[@]}"; do
	if ! (cd "${home_dir}" && opencode session delete --pure "${session}" >/dev/null 2>&1); then
		echo "WARNING: could not delete OpenCode session ${session}." >&2
		failed=$((failed + 1))
	fi
done

for path in "${target_paths[@]}"; do
	if ! rm -rf --one-file-system -- "${path}"; then
		echo "WARNING: could not remove ${path}." >&2
		failed=$((failed + 1))
	fi
done

# A Claude Code project directory goes only when nothing, such as memory/,
# is left in it.
for project in "${claude_projects[@]}"; do
	rmdir --ignore-fail-on-non-empty -- "${project}" 2>/dev/null || true
done

if [[ ${failed} -gt 0 ]]; then
	echo "Removed with ${failed} failure(s)." >&2
	exit 1
fi
echo "Removed."
