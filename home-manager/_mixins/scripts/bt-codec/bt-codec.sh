#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset
set +o pipefail  # Disable pipefail

# Get Bluetooth card
BT_CARD=$(pactl list short | grep bluez_card | cut -f 2)
if [ -z "${BT_CARD}" ]; then
    echo "--"
    exit 0
fi

function set_profile() {
    local PROFILE="${1}"
    pactl set-card-profile "${BT_CARD}" "${PROFILE}"
}

function active_codec() {
    case "$(active_profile)" in
      "A2DP") pactl list | grep "Active Profile" | grep a2dp-sink | cut -d':' -f 2 | sed 's/ //g';;
      "HFP") pactl list | grep "Active Profile" | grep headset-head-unit | cut -d':' -f 2 | sed 's/ //g';;
      *) echo "";;
    esac
}

function active_profile() {
    local PROFILE=""
    PROFILE=$(pactl list | grep "Active Profile" | cut -d':' -f 2 | grep -v "pro" | grep "-" | sed 's/ //g' | cut -d'-' -f 1)
    case "${PROFILE}" in
      "a2dp") echo "A2DP";;
      "headset") echo "HFP";;
      *) echo "";;
    esac
}

function available_codecs() {
    if [ -n "$(active_profile)" ]; then
        if [ "${1}" == "pretty" ]; then
            pactl send-message "/card/${BT_CARD}/bluez" list-codecs | jq '.[] | .description' | sed 's/"//g'
        else
            pactl send-message "/card/${BT_CARD}/bluez" list-codecs | jq '.[] | .description' | sed 's/"//g' | tr '[:upper:]' '[:lower:]' | tr '-' '_'
        fi
    fi
}

case "${1}" in
  a2dp) set_profile a2dp-sink;;
  hfp) set_profile headset-head-unit;;
  codec) if [ -n "$(active_profile)" ]; then
            pactl list | grep "$(active_codec):" | grep "available: yes" | cut -d')' -f 1 | cut -d',' -f 2 | sed 's/codec//g' | sed 's/ //g'
         else
           echo "--"
         fi;;
  codecs) available_codecs pretty;;
  profile) active_profile;;
  switch)
    CODEC_CURRENT=$(pactl list | grep "$(active_codec):" | grep "available: yes" | cut -d')' -f 1 | cut -d',' -f 2 | sed 's/codec//g' | sed 's/ //g' | tr '[:upper:]' '[:lower:]' | tr '-' '_')
    CODEC_NEXT="$(available_codecs | sed -n "/${CODEC_CURRENT}/{n;p;}")"
    if [ -z "${CODEC_NEXT}" ]; then
        CODEC_NEXT=$(available_codecs | head -n 1)
    fi
    echo "Switching from ${CODEC_CURRENT} to ${CODEC_NEXT}"
    case "$(active_profile)" in
      "A2DP") set_profile "a2dp-sink-${CODEC_NEXT}";;
      "HFP") set_profile "headset-head-unit-${CODEC_NEXT}";;
    esac
    ;;
  toggle)
    case "$(active_profile)" in
      "A2DP") set_profile headset-head-unit;;
      "HFP") set_profile a2dp-sink;;
    esac
    "${0}" codec;;
  *) echo "Usage: ${0} {a2dp|hfp|codec|codecs|profile|toggle}";;
esac
