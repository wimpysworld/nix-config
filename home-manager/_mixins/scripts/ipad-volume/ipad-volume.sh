#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset
set +o pipefail  # Disable pipefail

if [ -z "${1}" ]; then
  echo "Usage: $(basename "${0}") {set|status|vol-down|vol-up}"
  exit 0
fi

SINK_ID=""
for ID in $(pulsemixer --list-sinks | grep "WirePlumber \[export\]" | cut -d':' -f3 | cut -d',' -f1 | sed 's/ //g'); do
  SINK_ID=$(echo "${ID}" | cut -d'-' -f3)
  PLAYER_SINK=$(pactl list short sink-inputs | grep "${SINK_ID}" | cut -f3)
  PLAYER_CLIENT=$(pactl list short clients | grep ^"${PLAYER_SINK}" | cut -f3)
  if [ "${PLAYER_CLIENT}" == "wireplumber" ]; then
    break
  fi
done

case "${1}" in
  status)
    STATUS="--"
    if [ -n "${SINK_ID}" ]; then
      STATUS="$(pulsemixer --get-volume --id "${SINK_ID}" | cut -d' ' -f1)%"
    fi
    echo "${STATUS}"
    ;;
  vol-down)
    if [ -n "${SINK_ID}" ]; then
      pulsemixer --id "${SINK_ID}" --change-volume -5
    fi
    ${0} status
    ;;
  vol-up)
    if [ -n "${SINK_ID}" ]; then
      pulsemixer --id "${SINK_ID}" --change-volume 5
    fi
    ${0} status
    ;;
  set)
    if [ -n "${SINK_ID}" ]; then
      pulsemixer --id "${SINK_ID}" --set-volume "${2}"
    fi
    ${0} status
    ;;
esac

