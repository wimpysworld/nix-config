#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset
set +o pipefail  # Disable pipefail

function get_default_source() {
    pactl info | grep "Default Source" | cut -d':' -f2 | sed 's/ //g'
}

function set_default_source() {
    pactl set-default-source "$(pactl list short sources | grep "${1}" | grep -v monitor | cut -f 2)"
}

function get_all_sources() {
    pactl list short sources | grep -v monitor | cut -f 2
}

case "${1}" in
  blue*)
      set_default_source bluez_input
      ${0} status;;
  evo4)
      set_default_source Audient_EVO4
      ${0} status;;
  ssl2)
      set_default_source Solid_State_Logic_SSL_2
      ${0} status;;
  usb)
      HOST="$(hostnamectl hostname)"
      case "${HOST}" in
        phasma) ${0} ssl2;;
        vader)  ${0} ssl2;;
      esac
      ;;
  status)
    SINK="$(get_default_source)"
    case "${SINK}" in
      *bluez*) echo "Bluetooth";;
      *EVO4*) echo "EVO4";;
      *SSL_2*) echo "SSL 2";;
    esac
    ;;
  *) echo "Usage: ${0} {bluetooth|evo4|ssl2|status}";;
esac
