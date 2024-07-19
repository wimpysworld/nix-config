#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset
set +o pipefail  # Disable pipefail

function get_default_sink() {
    pactl info | grep "Default Sink" | cut -d':' -f2 | sed 's/ //g'
}

function set_default_sink() {
    pactl set-default-sink "$(pactl list short sinks | grep "${1}" | cut -f 2)"
}

function get_all_sinks() {
    pactl list short sinks | cut -f 2
}

case "${1}" in
  blue*)
      set_default_sink bluez_output
      ${0} status;;
  gtw_270)
      set_default_sink EPOS_GSA_70S
      ${0} status;;
  evo4)
      set_default_sink Audient_EVO4
      ${0} status;;
  quantum_tws)
      set_default_sink JBL_Quantum_TWS
      ${0} status;;
  ssl2)
      set_default_sink Solid_State_Logic_SSL_2
      ${0} status;;
  inzone)
      set_default_sink Sony_INZONE_Buds
      ${0} status;;
  usb)
      HOST="$(hostnamectl hostname)"
      case "${HOST}" in
        vader)  ${0} ssl2;;
        phasma) ${0} ssl2;;
      esac
      ;;
  vr_p10)
      set_default_sink VR_P10_Dongle
      ${0} status;;
  status)
    SINK="$(get_default_sink)"
    case "${SINK}" in
      *bluez*) echo "Bluetooth";;
      *EPOS_GSA_70S*) echo "GTW 270";;
      *EVO4*) echo "EVO4";;
      *INZONE*) echo "INZONE";;
      *Quantum_TWS*) echo "JBL TWS";;
      *SSL_2*) echo "SSL 2";;
      *VR_P10*) echo "VR P10";;
    esac
    ;;
  *) echo "Usage: ${0} {bluetooth|epos|evo4|inzone|jbl_quantum_tws|ssl2|vr_p10|status}";;
esac
