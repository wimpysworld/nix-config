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
screenshot="󰹑 Screenshot"
picker="󰏘 Colour Picker"

# Power
session="󰐦 Session"

menu=""
if command -v fuzzel-wifi >/dev/null 2>&1; then
	menu="$wifi\n"
fi
menu="$menu$bluetooth\n$audio\n$screenshot"
if command -v fuzzel-picker >/dev/null 2>&1; then
	menu="$menu\n$picker"
fi
menu="$menu\n\n$control_center\n$session"

selected=$(echo -e "$menu" |
	fuzzel --dmenu --prompt "󱑞 " --lines=8 --width=21)

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
"$screenshot")
	fuzzel-capture
	;;
"$picker")
	fuzzel-picker
	;;
"$session")
	wleave-session
	;;
esac
