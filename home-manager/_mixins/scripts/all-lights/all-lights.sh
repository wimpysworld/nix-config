#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset

STATE="${1}"
HOST="$(hostnamectl hostname)"

if [[ "${HOST}" != *"vader"* ]]; then
  exit
fi

case ${STATE} in
  on|ON|1)
    hue-lights on
    ;;
  off|OFF|0)
    key-lights off
    hue-lights off
    ;;
  streaming|default|coding)
    key-lights on 15 0
    hue-lights default
    ;;
  gaming)
    key-lights on 15 0
    hue-lights gaming
    ;;
esac
