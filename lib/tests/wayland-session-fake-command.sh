#!/usr/bin/env bash

set -euo pipefail

command_name=$1
shift

record() {
	local argument

	printf '%s' "$command_name" >>"$FAKE_EVENT_LOG"
	for argument in "$@"; do
		printf ' <%s>' "$argument" >>"$FAKE_EVENT_LOG"
	done
	printf '\n' >>"$FAKE_EVENT_LOG"
}

selected() {
	local candidate
	local -a candidates=()
	local selection=${1:-}
	local value=$2

	IFS='|' read -r -a candidates <<<"$selection"
	for candidate in "${candidates[@]}"; do
		if [[ $candidate == "$value" ]]; then
			return 0
		fi
	done
	return 1
}

case "$command_name" in
systemctl)
	record "$@"
	if selected "${FAKE_SYSTEMCTL_FAILURES:-}" "$*"; then
		exit "${FAKE_SYSTEMCTL_STATUS:-7}"
	fi
	if [[ $* == "--user show --property=Wants --value "* ]]; then
		printf '%s\n' "${FAKE_SYSTEMCTL_WANTS:-}"
	elif [[ $* == "--user show --property=LoadState --value "* ]]; then
		unit=${*: -1}
		if selected "${FAKE_SYSTEMCTL_NOT_FOUND:-}" "$unit"; then
			printf 'not-found\n'
		else
			printf 'loaded\n'
		fi
	elif [[ $* == "--user show --property=ActiveState --value "* ]]; then
		unit=${*: -1}
		if selected "${FAKE_SYSTEMCTL_INACTIVE:-}" "$unit"; then
			printf 'inactive\n'
		else
			printf 'active\n'
		fi
	fi
	;;
dbus-update-activation-environment)
	record "$@"
	exit "${FAKE_DBUS_STATUS:-0}"
	;;
wayland-session-cleanup)
	record "$@"
	if selected "${FAKE_CLEANUP_FAILURES:-}" "${1:-}"; then
		printf 'wayland-session-cleanup: fake %s warning\n' "${1:-unknown}" >&2
		exit "${FAKE_CLEANUP_STATUS:-9}"
	fi
	;;
wayland-session-adapter)
	record "$@"
	exit "${FAKE_ADAPTER_STATUS:-0}"
	;;
playerctl)
	record "$@"
	exit "${FAKE_PLAYERCTL_STATUS:-0}"
	;;
fake-launcher)
	record "$@"
	exit "${FAKE_LAUNCHER_STATUS:-0}"
	;;
unbuffer)
	exec "$@"
	;;
hostname)
	printf 'test-host\n'
	;;
bluetoothctl)
	record "$@"
	;;
*)
	printf 'unexpected fake command: %s\n' "$command_name" >&2
	exit 127
	;;
esac
