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

selected=$(echo -e "$wifi\n$bluetooth\n$audio\n$picker\n\n$session_obliterate\n$logout" |
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
