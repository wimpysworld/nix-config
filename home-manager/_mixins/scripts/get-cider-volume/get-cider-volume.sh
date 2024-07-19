#!/usr/bin/env bash

set +e  # Disable errexit
set +o pipefail  # Disable pipefail

if ! playerctl --no-messages -p cider status; then
  echo "--"
  exit 0
fi

VOL=$(playerctl -p cider volume)
STATUS=$(playerctl -p cider status)

if [ -z "${VOL}" ]; then
  echo "--"
else
  # If Cider has not had the volume changed via MPRIS then MPRIS reports 0.000000
  # This is a workaround to get the actual volume from PulseAudio
  if [ "${VOL}" == "0.000000" ] && [ "${STATUS}" == "Playing" ]; then
    for ID in $(pulsemixer --list-sinks | grep "Chromium" | cut -d':' -f3 | cut -d',' -f1 | sed 's/ //g'); do
      SINK_NUM=$(echo "${ID}" | cut -d'-' -f3)
      PLAYER_SINK=$(pactl list short sink-inputs | grep "${SINK_NUM}" | cut -f3)
      PLAYER_CLIENT=$(pactl list short clients | grep ^"${PLAYER_SINK}" | cut -f3)
      if [ "${PLAYER_CLIENT}" == "cider" ]; then
        SINK_ID="${ID}"
        break
      fi
    done
    echo "$(pulsemixer --get-volume --id "${SINK_ID}" | cut -d' ' -f1)%"
  else
    echo "$(echo "100 * ${VOL}" | bc -l | cut -d'.' -f1)%"
  fi
fi
