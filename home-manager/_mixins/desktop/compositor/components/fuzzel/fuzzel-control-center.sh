#!/usr/bin/env bash
# Launch a system control application from a Fuzzel menu.

# Applications
volume="󰕾 Volume"
bluetooth="󰂯 Bluetooth"
network="󰈀 Network"
printers="󱁗 Printers"
displays="󱋆 Displays"
mouse=" Mouse"
disks="󰋊 Disks"
formatter="󰉉 USB Formatter"
usb_imager="󱊞 USB Imager"
cpu=" CPU"
firmware="󰉁 Firmware"

menu="$volume\n$bluetooth\n$network\n$printers\n$displays\n$mouse\n$disks\n$formatter\n$usb_imager\n$cpu\n$firmware"

selected=$(echo -e "$menu" | fuzzel --dmenu --prompt "󰒓 " --lines=11 --width=21) || exit 0

case $selected in
"$volume") app="pwvucontrol" ;;
"$bluetooth") app="overskride" ;;
"$network") app="nm-connection-editor" ;;
"$printers") app="system-config-printer" ;;
"$displays") app="wdisplays" ;;
"$mouse") app="piper" ;;
"$disks") app="gnome-disk-utility" ;;
"$formatter") app="com.github.djaler.formatter" ;;
"$usb_imager") app="usbimager" ;;
"$cpu") app="cpu-x" ;;
"$firmware") app="gnome-firmware" ;;
*) exit 0 ;;
esac

# Detach the application so it outlives the menu process.
exec setsid --fork "$app"
