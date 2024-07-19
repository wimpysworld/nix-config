#!/usr/bin/env bash

set +u  # Disable nounset
set +o pipefail  # Disable pipefail

case "${1}" in
    status)
        #wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -woi "muted"
        STATE=$(pactl get-source-mute @DEFAULT_SOURCE@ | cut -d':' -f 2 | sed 's/ //g' | sed 's/yes/muted/' | sed 's/no/on/')
        echo "${STATE^^}"
        ;;
    off|on|toggle)
        pactl set-source-mute @DEFAULT_SOURCE@ "${1}"
        #wpctl set-mute @DEFAULT_AUDIO_SOURCE@ "${1}"
        STATE=$("${0}" status)
        ICON="emblem-unreadable"
        if [ "${STATE}" == "ON" ]; then
            ICON="audio-input-microphone"
        fi
        notify-desktop "Microphone Status" "Microphone is ${STATE}" --icon="${ICON}" >/dev/null
        ;;
    *) echo "Usage: $0 {status|toggle}";;
esac
