#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset
set +o pipefail  # Disable pipefail

HOSTNAME=$(hostname -s)
state=$(bluetoothctl show | grep 'Powered:' | awk '{ print $2 }')
if [[ $state == 'yes' ]]; then
  bluetoothctl discoverable off
  bluetoothctl power off
  fyi --urgency=low --app-name="Bluetooth Toggle" --icon=bluetooth-disabled "Bluetooth disconnected" "Your Bluetooth devices have been disconnected."
else
  bluetoothctl power on
  bluetoothctl discoverable on
  if [ "$HOSTNAME" == "zannah" ]; then
    bluetoothctl connect E4:50:EB:7D:86:22
  fi
  fyi --urgency=low --app-name="Bluetooth Toggle" --icon=bluetooth-active "Bluetooth connected" "Your Bluetooth devices have been connected."
fi
