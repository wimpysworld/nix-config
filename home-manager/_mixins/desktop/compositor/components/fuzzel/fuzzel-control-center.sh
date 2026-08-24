#!/usr/bin/env bash
# Launch a system control application from a Fuzzel menu.

# Applications
volume="󰕾 Volume"
effects="󱑽 Effects"
bluetooth="󰂯 Bluetooth"
network="󰈀 Network"
wifi="󰖩 WiFi"
printers="󱁗 Printers"
displays="󱋆 Displays"
mouse=" Mouse"
disks="󰋊 Disks"
usb_imager="󱊞 USB Imager"
system=" System"
firmware="󰉁 Firmware"

menu="$volume\n$effects\n$bluetooth\n$network\n$wifi\n$printers\n$displays\n$mouse\n$disks\n$usb_imager\n$system\n$firmware"

selected=$(echo -e "$menu" | fuzzel --dmenu --prompt "󰒓 " --lines=12 --width=21) || exit 0

case $selected in
  "$volume") app="pwvucontrol" ;;
  "$effects") app="easyeffects" ;;
  "$bluetooth") app="overskride" ;;
  "$network") app="nm-connection-editor" ;;
  "$wifi") app="iwgtk" ;;
  "$printers") app="system-config-printer" ;;
  "$displays") app="wdisplays" ;;
  "$mouse") app="piper" ;;
  "$disks") app="gnome-disk-utility" ;;
  "$usb_imager") app="usbimager" ;;
  "$system") app="cpu-x" ;;
  "$firmware") app="gnome-firmware" ;;
  *) exit 0 ;;
esac

# Detach the application so it outlives the menu process.
exec setsid --fork "$app"
