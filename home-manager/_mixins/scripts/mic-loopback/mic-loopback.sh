#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset
set +o pipefail  # Disable pipefail

LOOPBACK_NAME="Mic-Loopback"
LOOPBACK_ID=""
if pidof -q pw-loopback; then
    LOOPBACK_ID="$(pulsemixer --list-sinks | grep "${LOOPBACK_NAME}" | cut -d':' -f3 | sed 's/ //g' | cut -d',' -f1)"
fi

case "${1}" in
    status)
        STATUS="Off"
        if pidof -q pw-loopback; then
            STATUS="$(pulsemixer --get-volume --id "${LOOPBACK_ID}")%"
        fi
        echo "Loop ${STATUS}"
        ;;
    off)
        pkill pw-loopback 2>/dev/null
        ${0} status
        ;;
    on)
        pw-loopback --name "${LOOPBACK_NAME}" --group "${LOOPBACK_NAME}" --delay 0 --latency 0 -m '[[]]' &
        ${0} status
        ;;
    toggle)
        if pidof -q pw-loopback; then
            ${0} off
        else
            ${0} on
        fi
        ;;
    vol-down)
        if [ -n "${LOOPBACK_ID}" ]; then
            pulsemixer --id "${LOOPBACK_ID}" --change-volume -10
        fi
        ${0} status
        ;;
    vol-up)
        if [ -n "${LOOPBACK_ID}" ]; then
            pulsemixer --id "${LOOPBACK_ID}" --change-volume 10
        fi
        ${0} status
        ;;
    set)
        if [ -n "${LOOPBACK_ID}" ]; then
            pulsemixer --id "${LOOPBACK_ID}" --set-volume "${2}"
        fi
        ${0} status
        ;;
    *) echo "Usage: $0 {set|on|off|status|toggle|vol-down|vol-up}";;
esac
