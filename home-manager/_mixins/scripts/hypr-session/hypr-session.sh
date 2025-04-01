#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset
HOSTNAME=$(hostname -s)

function bluetooth_devices() {
  case "$1" in
    connect|disconnect)
    if [ "$HOSTNAME" == "phasma" ]; then
      bluetoothctl "$1" E4:50:EB:7D:86:22
    fi
    ;;
  esac
}

function session_start() {
  # Restart the desktop portal services in the correct order
  restart-portals
  for INDICATOR in udiskie syncthingtray maestral-gui; do
    if /run/current-system/sw/bin/systemctl --user list-unit-files "$INDICATOR.service" &>/dev/null; then
      if ! /run/current-system/sw/bin/systemctl --user is-active "$INDICATOR" &>/dev/null; then
        /run/current-system/sw/bin/systemctl --user restart "$INDICATOR"
      fi
    fi
  done
  bluetooth_devices connect
}

function session_stop() {
  playerctl --all-players pause
  hypr-activity clear
}

OPT="help"
if [ -n "$1" ]; then
  OPT="$1"
fi

case "$OPT" in
    start) session_start;;
    lock)
        pkill -u "$USER" wlogout
        sleep 0.5
        hyprlock --immediate;;
    logout)
        session_stop
        hyprctl dispatch exit;;
    reboot)
        session_stop
        /run/current-system/sw/bin/systemctl reboot;;
    shutdown)
        session_stop
        /run/current-system/sw/bin/systemctl poweroff;;
    *) echo "Usage: $(basename "$0") {start|lock|logout|reboot|shutdown}";
        exit 1;;
esac
