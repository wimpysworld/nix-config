#!/usr/bin/env bash

set +e # Disable errexit
set +u # Disable nounset
HOSTNAME=$(hostname -s)

function bluetooth_devices() {
	case "$1" in
	connect | disconnect)
		if [ "$HOSTNAME" == "phasma" ]; then
			bluetoothctl "$1" E4:50:EB:7D:86:22
		fi
		;;
	esac
}

function session_start() {
	local LAYOUT=""
	bluetooth_devices connect
	LAYOUT="$(localectl | grep "X11 Layout" | cut -d':' -f2 | sed 's/ //g')"
	if [ -z "$LAYOUT" ]; then
		LAYOUT="gb"
	fi
	hyprctl keyword input:kb_layout "${LAYOUT}"
	dconf write /org/gnome/desktop/wm/preferences/button-layout "':appmenu'"
	# Restore the previous session and start the auto-save daemon.
	hypr-layout load 2>/dev/null || true
	hypr-layout start-daemon 2>/dev/null || true
}

function session_stop() {
	# Save the current session before stopping (if one is active).
	hypr-layout save 2>/dev/null || true
	# Stop the auto-save daemon.
	hypr-layout stop-daemon 2>/dev/null || true
	playerctl --all-players pause
}

OPT="help"
if [ -n "$1" ]; then
	OPT="$1"
fi

case "$OPT" in
start) session_start ;;
lock)
	pkill -u "$USER" wlogout
	sleep 0.5
	hyprlock --immediate
	;;
logout)
	session_stop
	hyprctl dispatch exit
	;;
reboot)
	session_stop
	/run/current-system/sw/bin/systemctl reboot
	;;
shutdown)
	session_stop
	/run/current-system/sw/bin/systemctl poweroff
	;;
*)
	echo "Usage: $(basename "$0") {start|lock|logout|reboot|shutdown}"
	exit 1
	;;
esac
