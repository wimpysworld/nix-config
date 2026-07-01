#!/usr/bin/env bash

usage() {
	echo "Usage: purge-root-nix-profiles [--apply] [--include-root-state]"
	echo ""
	echo "Find root-owned Nix profile and bootstrap cruft."
	echo ""
	echo "Options:"
	echo "  --apply               Remove safe candidates. Dry-run is the default."
	echo "  --include-root-state  Also remove cautious /root Nix state candidates."
	echo "  -h, --help            Show this help."
}

apply=false
include_root_state=false

while [[ $# -gt 0 ]]; do
	case "${1}" in
		--apply)
			apply=true
			;;
		--include-root-state)
			include_root_state=true
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

sudo_available=false
if [[ "${EUID}" -eq 0 ]]; then
	sudo_cmd=()
elif [[ -x /run/wrappers/bin/sudo ]]; then
	sudo_available=true
	sudo_cmd=(/run/wrappers/bin/sudo)
elif command -v sudo >/dev/null 2>&1; then
	sudo_available=true
	sudo_cmd=("$(command -v sudo)")
elif "${apply}"; then
	echo "ERROR: sudo is required when running --apply as a non-root user." >&2
	exit 1
else
	sudo_cmd=()
fi

root_state_not_inspected=false
if ! "${apply}" && [[ "${EUID}" -ne 0 ]] && { ! "${sudo_available}" || ! "${sudo_cmd[@]}" -n true 2>/dev/null; }; then
	root_state_not_inspected=true
fi

safe_candidates=()
cautious_candidates=()
skipped_live=()

path_exists() {
	test -e "${1}" || test -L "${1}" || { "${sudo_available}" && "${sudo_cmd[@]}" test -e "${1}" 2>/dev/null; } || { "${sudo_available}" && "${sudo_cmd[@]}" test -L "${1}" 2>/dev/null; }
}

resolved_path() {
	readlink -f "${1}" 2>/dev/null || { "${sudo_available}" && "${sudo_cmd[@]}" readlink -f "${1}" 2>/dev/null; } || true
}

is_live_generation() {
	local current="${1}"
	local candidate="${2}"
	local current_target
	local candidate_target

	if ! test -L "${current}" && { ! "${sudo_available}" || ! "${sudo_cmd[@]}" test -L "${current}" 2>/dev/null; }; then
		return 1
	fi

	current_target=$(resolved_path "${current}")
	candidate_target=$(resolved_path "${candidate}")

	[[ -n "${current_target}" && "${current_target}" == "${candidate_target}" ]]
}

append_inactive_generation_links() {
	local directory="${1}"
	local path
	local base
	local stem
	local current

	if ! path_exists "${directory}"; then
		return 0
	fi

	if [[ -r "${directory}" && -x "${directory}" ]]; then
		find_command=(find)
	elif "${sudo_available}"; then
		find_command=("${sudo_cmd[@]}" find)
	else
		return 0
	fi

	while IFS= read -r -d '' path; do
		base=$(basename "${path}")
		if [[ ! "${base}" =~ ^(.+)-([0-9]+)-link$ ]]; then
			continue
		fi

		stem="${BASH_REMATCH[1]}"
		current="${directory}/${stem}"

		if is_live_generation "${current}" "${path}"; then
			skipped_live+=("${path}")
		else
			safe_candidates+=("${path}")
		fi
	done < <("${find_command[@]}" "${directory}" -maxdepth 1 -type l -name "*-[0-9]*-link" -print0 2>/dev/null | sort -z)
}

append_cautious_candidate() {
	local path="${1}"

	if path_exists "${path}"; then
		cautious_candidates+=("${path}")
	fi
}

print_paths() {
	local title="${1}"
	shift

	echo "${title}"
	if [[ $# -eq 0 ]]; then
		echo "  None"
		return 0
	fi

	for path in "$@"; do
		echo "  ${path}"
	done
}

remove_paths() {
	local title="${1}"
	shift
	local path

	echo "${title}"
	if [[ $# -eq 0 ]]; then
		echo "  None"
		return 0
	fi

	for path in "$@"; do
		echo "Removing: ${path}"
		"${sudo_cmd[@]}" rm -rv -- "${path}"
	done
}

append_inactive_generation_links "/nix/var/nix/profiles/per-user/root"
append_inactive_generation_links "/root/.local/state/nix/profiles"

append_cautious_candidate "/root/.nix-profile"
append_cautious_candidate "/root/.nix-defexpr"
append_cautious_candidate "/root/.nix-channels"
append_cautious_candidate "/root/.cache/nix"
append_cautious_candidate "/root/.config/nix"
append_cautious_candidate "/root/.local/share/nix"
append_cautious_candidate "/root/.local/state/nix"

if "${apply}"; then
	echo "Mode: apply"
	remove_paths "Safe candidates:" "${safe_candidates[@]}"

	if "${include_root_state}"; then
		remove_paths "Cautious /root Nix state candidates:" "${cautious_candidates[@]}"
	else
		print_paths "Cautious /root Nix state candidates (not removed without --include-root-state):" "${cautious_candidates[@]}"
	fi
else
	echo "Mode: dry-run"
	print_paths "Safe candidates:" "${safe_candidates[@]}"
	print_paths "Cautious /root Nix state candidates (not removed without --include-root-state):" "${cautious_candidates[@]}"
	if "${root_state_not_inspected}"; then
		echo "Note: /root paths were not inspected because sudo is not available without a password."
		echo "Run with sudo for a full /root dry-run."
	fi
	echo ""
	echo "Run with --apply to remove safe candidates."
	echo "Run with --apply --include-root-state to also remove cautious /root Nix state candidates."
fi

print_paths "Live generation links skipped:" "${skipped_live[@]}"
