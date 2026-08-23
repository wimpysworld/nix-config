#!/usr/bin/env bash

set +e
set +u

if (( $# < 3 )); then
	echo "wayland-session: invalid lifecycle configuration" >&2
	exit 2
fi

session_target=$1
environment_count=$2
shift 2

if [[ ! $environment_count =~ ^[0-9]+$ ]] || (( $# < environment_count + 1 )); then
	echo "wayland-session: invalid environment configuration" >&2
	exit 2
fi

session_environment=("${@:1:environment_count}")
shift "$environment_count"

HOSTNAME=$(hostname -s)

function bluetooth_devices() {
	case "$1" in
	connect | disconnect)
		if [ "$HOSTNAME" == "zannah" ]; then
			bluetoothctl "$1" E4:50:EB:7D:86:22
		fi
		;;
	esac
}

function prepare_exit() {
	playerctl --all-players pause
}

function start_session() {
	local recovery_status=0

	if [ -z "$session_target" ]; then
		return 0
	fi

	wayland-session-cleanup recover || recovery_status=$?
	if [ "$recovery_status" -ne 0 ]; then
		printf 'wayland-session: recovery failed with code %d, startup will continue\n' \
			"$recovery_status" >&2
	fi
	dbus-update-activation-environment --systemd "${session_environment[@]}" || return
	systemctl --user start "$session_target"
}

function prepare_logout() {
	local status=0
	local step_status

	prepare_exit
	step_status=$?
	if [ "$step_status" -ne 0 ]; then
		status=$step_status
	fi

	wayland-session-cleanup prepare
	step_status=$?
	if [ "$status" -eq 0 ] && [ "$step_status" -ne 0 ]; then
		status=$step_status
	fi

	return "$status"
}

function require_adapter() {
	if ! command -v wayland-session-adapter >/dev/null 2>&1; then
		echo "wayland-session: no compositor adapter is available for $1" >&2
		exit 1
	fi
}

case "${1:-}" in
start)
	start_session
	status=$?
	if [ "$status" -ne 0 ]; then
		exit "$status"
	fi
	bluetooth_devices connect
	;;
lock)
	pkill -u "$USER" -f wleave
	sleep 0.5
	veila lock
	;;
obliterate)
	require_adapter obliterate
	prepare_exit
	wayland-session-adapter close-windows
	;;
logout)
	systemctl --user start --no-block wayland-session-logout.service
	;;
logout-action)
	require_adapter logout
	prepare_logout
	prepare_status=$?
	wayland-session-adapter logout
	adapter_status=$?
	if [ "$adapter_status" -ne 0 ]; then
		exit "$adapter_status"
	fi
	exit "$prepare_status"
	;;
reboot)
	prepare_exit
	/run/current-system/sw/bin/systemctl reboot
	;;
shutdown)
	prepare_exit
	/run/current-system/sw/bin/systemctl poweroff
	;;
*)
	echo "Usage: $(basename "$0") {start|lock|obliterate|logout|reboot|shutdown}"
	exit 1
	;;
esac
