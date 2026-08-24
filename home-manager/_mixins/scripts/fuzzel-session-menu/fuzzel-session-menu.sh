#!/usr/bin/env bash

set +e
set +u
set +o pipefail

# Session
control_center="󰙵 Control Center"
session_obliterate="󰚑 Session Obliterate"

# Utilities
wifi="󱚾 WiFi"
bluetooth="󰂯 Bluetooth"
audio="󰕾 Audio"
picker="󰏘 Colour Picker"

# Power
logout="󰐦 Logout"

menu="$wifi\n$bluetooth\n$audio"
if command -v fuzzel-picker >/dev/null 2>&1; then
	menu="$menu\n$picker"
fi
menu="$menu\n\n$control_center\n$session_obliterate\n$logout"

selected=$(echo -e "$menu" |
	fuzzel --dmenu --prompt "󱑞 " --lines=9 --width=21)

case $selected in
"$control_center")
	fuzzel-control-center
	;;
"$session_obliterate")
	wayland-session obliterate
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
"$picker")
	fuzzel-picker
	;;
"$logout")
	wleave-session
	;;
esac
