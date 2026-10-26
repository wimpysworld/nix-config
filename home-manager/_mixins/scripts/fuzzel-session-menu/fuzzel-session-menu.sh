#!/usr/bin/env bash

set +e
set +u
set +o pipefail

# Session
control_center="󰙵 Control Center"

# Utilities
wifi="󱚾 WiFi"
bluetooth="󰂯 Bluetooth"
audio="󰕾 Audio"
virtualcam_start="󰄀 Start Virtualcam"
virtualcam_stop="󰗟 Stop Virtualcam"
screenshot="󱎴 Screenshot"
picker="󰏘 Colour Picker"
window_layout="󰹫 Window Layout"
keyboard_shortcuts="󰌌 Keyboard shortcuts"
connections="󰖟 Connections"

# Power
session="󰐦 Session"

menu=""
if command -v fuzzel-wifi >/dev/null 2>&1; then
	menu="$wifi\n"
fi
menu="$menu$bluetooth\n$audio\n"
if command -v virtualcam >/dev/null 2>&1; then
	if virtualcam status >/dev/null 2>&1; then
		menu="$menu$virtualcam_stop\n"
	else
		menu="$menu$virtualcam_start\n"
	fi
fi
menu="$menu$screenshot"
if command -v fuzzel-picker >/dev/null 2>&1; then
	menu="$menu\n$picker"
fi
menu="$menu\n"
if command -v fuzzel-layout >/dev/null 2>&1; then
	menu="$menu\n$window_layout"
fi
if command -v fuzzel-keybindings >/dev/null 2>&1; then
	menu="$menu\n$keyboard_shortcuts"
fi
if command -v fuzzel-connections >/dev/null 2>&1; then
	menu="$menu\n$connections"
fi
menu="$menu\n$control_center\n$session"

selected=$(echo -e "$menu" |
	fuzzel --dmenu --prompt "󱑞 " --lines=12 --width=21)

case $selected in
"$control_center")
	fuzzel-control-center
	;;
"$wifi")
	fuzzel-wifi
	;;
"$bluetooth")
	fuzzel-bluetooth
	;;
"$audio")
	fuzzel-audio
	;;
"$virtualcam_start" | "$virtualcam_stop")
	virtualcam toggle
	;;
"$screenshot")
	fuzzel-capture
	;;
"$picker")
	fuzzel-picker
	;;
"$window_layout")
	fuzzel-layout
	;;
"$keyboard_shortcuts")
	fuzzel-keybindings
	;;
"$connections")
	fuzzel-connections
	;;
"$session")
	wleave-session
	;;
esac
