#!/usr/bin/env bash

set +e
set +u

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

function require_adapter() {
	if ! command -v wayland-session-adapter >/dev/null 2>&1; then
		echo "wayland-session: no compositor adapter is available for $1" >&2
		exit 1
	fi
}

case "${1:-}" in
start)
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
	require_adapter logout
	prepare_exit
	wayland-session-adapter logout
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
