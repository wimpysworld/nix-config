#!/usr/bin/env bash

set +e
set +u
set +o pipefail

# Session
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
menu="$menu\n\n$session_obliterate\n$logout"

selected=$(echo -e "$menu" |
	fuzzel --dmenu --prompt "󱑞 " --lines=8 --width=21)

case $selected in
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
