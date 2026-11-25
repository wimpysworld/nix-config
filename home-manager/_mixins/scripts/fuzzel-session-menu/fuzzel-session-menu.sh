#!/usr/bin/env bash

set +e
set +u
set +o pipefail

# Primary controls
airplane_off="󰀞 Airplane Mode "
airplane_on="󰀝 Airplane Mode "
wifi="󱚾 WiFi"
bluetooth="󰂯 Bluetooth"
audio="󰕾 Audio"
virtualcam_off="󰗟 Virtualcam "
virtualcam_on="󰄀 Virtualcam "
screenshot="󱎴 Screenshot"
picker="󰏘 Colour Picker"
session="󰐦 Session"

# Secondary tools
connections="󰖟 Connections"
control_center="󰙵 Control Center"
window_layout="󰹫 Window Layout"
keyboard_shortcuts="󰌌 Keyboard shortcuts"

menu_items=()
if command -v airplane-mode >/dev/null 2>&1 && airplane-mode available >/dev/null 2>&1; then
	if airplane-mode status >/dev/null 2>&1; then
		menu_items+=("$airplane_on")
	else
		menu_items+=("$airplane_off")
	fi
fi
if command -v fuzzel-wifi >/dev/null 2>&1; then
	menu_items+=("$wifi")
fi
menu_items+=("$bluetooth" "$audio")
if command -v virtualcam >/dev/null 2>&1; then
	if virtualcam status >/dev/null 2>&1; then
		menu_items+=("$virtualcam_on")
	else
		menu_items+=("$virtualcam_off")
	fi
fi
menu_items+=("$screenshot")
if command -v fuzzel-picker >/dev/null 2>&1; then
	menu_items+=("$picker")
fi
menu_items+=("$session")

menu_items+=("")
if command -v fuzzel-connections >/dev/null 2>&1; then
	menu_items+=("$connections")
fi
menu_items+=("$control_center")
if command -v fuzzel-layout >/dev/null 2>&1; then
	menu_items+=("$window_layout")
fi
if command -v fuzzel-keybindings >/dev/null 2>&1; then
	menu_items+=("$keyboard_shortcuts")
fi

selected=$(printf '%s\n' "${menu_items[@]}" |
	fuzzel --dmenu --prompt "󱑞 " --lines="${#menu_items[@]}" --width=21)

case $selected in
"$airplane_off" | "$airplane_on")
	airplane-mode toggle
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
"$virtualcam_off" | "$virtualcam_on")
	virtualcam toggle
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
"$connections")
	fuzzel-connections
	;;
"$control_center")
	fuzzel-control-center
	;;
"$window_layout")
	fuzzel-layout
	;;
"$keyboard_shortcuts")
	fuzzel-keybindings
	;;
esac
