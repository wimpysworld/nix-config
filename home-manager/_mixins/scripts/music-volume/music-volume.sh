#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset
set +o pipefail  # Disable pipefail

function set_vol() {
  local VOL="${1}"
  rhythmbox-client --no-start --set-volume "${VOL}"
}

function fade_vol() {
  local CHANGE=0
  # Check if $1 is empty
  if [ -z "${1}" ]; then
    return 1
  fi

  case "${1}" in
    up) CHANGE="0.01";;
    down) CHANGE="-0.01";;
  esac
  echo "Changing volume from ${VOLUME} to ${TARGET_VOLUME}"
  for SEQ in $(seq "${VOLUME}" ${CHANGE} "${TARGET_VOLUME}"); do
    set_vol "${SEQ}"
    sleep 0.05
  done
  echo "Volume is now ${TARGET_VOLUME}"
}

# Is rhythmbox-client in the path?
if ! command -v rhythmbox-client >/dev/null 2>&1; then
  echo "ERROR! rhythmbox-client not found, please install rhythmbox."
  exit 1
fi

TARGET_VOLUME="${1}"

if [ -z "${TARGET_VOLUME}" ]; then
  echo "No target volume provided. Quitting."
  exit 1
elif ! [[ ${TARGET_VOLUME} =~ ^[+-]?[0-9]+\.?[0-9]*$ ]]; then
  echo "Target volume is not a number. Quitting."
  exit 1
elif (( $(echo "${TARGET_VOLUME} < 0" | bc -l) )); then
  TARGET_VOLUME=0
elif (( $(echo "${TARGET_VOLUME} > 1" | bc -l) )); then
  TARGET_VOLUME=1
fi

# Get the volume. Float between 0 and 1.
VOLUME=$(rhythmbox-client --no-start --print-volume | cut -d' ' -f4 | cut -c1-4)
if [ -z "${VOLUME}" ]; then
  echo "Could not retrieve volume."
  exit 1
fi

if (( $(echo "${VOLUME} < ${TARGET_VOLUME}" | bc -l) )); then
  if (( $(echo "${TARGET_VOLUME} > 0" | bc -l) )); then
    rhythmbox-client --no-start --play
  fi
  fade_vol up "${TARGET_VOLUME}"
elif (( $(echo "${VOLUME} > ${TARGET_VOLUME}" | bc -l) )); then
  fade_vol down "${TARGET_VOLUME}"
  if (( $(echo "${TARGET_VOLUME} <= 0" | bc -l) )); then
    rhythmbox-client --no-start --pause
  fi
else
  echo "Volume is already ${TARGET_VOLUME}%"
fi
