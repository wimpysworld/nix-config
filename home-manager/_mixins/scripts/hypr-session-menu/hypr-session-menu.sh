#!/usr/bin/env bash

set +e          # Disable errexit
set +u          # Disable nounset
set +o pipefail # Disable pipefail

# Session
session_save="󰘛 Session Save"
session_reload="󰑓 Session Reload"
session_obliterate="󰚑 Session Obliterate"

# Utilities
wifi="󱚾 WiFi"
bluetooth="󰂯 Bluetooth"
audio="󰕾 Audio"
picker="󰏘 Colour Picker"

# Power
logout="󰐦 Logout"

selected=$(echo -e "$session_save\n$session_reload\n$session_obliterate\n\n$wifi\n$bluetooth\n$audio\n$picker\n\n$logout" |
	fuzzel --dmenu --prompt "󱑞 " --lines=10 --width=21)

case $selected in
"$session_save")
	hypr-session-core save
	;;
"$session_reload")
	hypr-session-core reload
	;;
"$session_obliterate")
	hypr-session-core clear
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
	fuzzel-hyprpicker
	;;
"$logout")
	hypr-session logout
	;;
esac
