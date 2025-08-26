#!/usr/bin/env bash

API_BASE="http://localhost:10767/api/v1/playback"
TIMEOUT="--max-time 2"

# Simple POST endpoints that map directly
SIMPLE_COMMANDS="play pause playpause next previous"

# shellcheck disable=SC2076
if [[ " $SIMPLE_COMMANDS " =~ " $1 " ]]; then
    #shellcheck disable=SC2086
    curl $TIMEOUT -X POST "$API_BASE/$1" >/dev/null 2>&1
elif [ "$1" = "prev" ]; then
    #shellcheck disable=SC2086
    curl $TIMEOUT -X POST "$API_BASE/previous" >/dev/null 2>&1
elif [ "$1" = "mute" ]; then
    # No native mute endpoint, so set volume to 0
    #shellcheck disable=SC2086
    curl $TIMEOUT -X POST -H "Content-Type: application/json" \
         -d '{"volume": 0.0}' "$API_BASE/volume" >/dev/null 2>&1
    echo "Muted"
elif [ "$1" = "vol" ]; then
    if [ -z "${2:-}" ]; then
        # Check if music is playing first
        #shellcheck disable=SC2086
        IS_PLAYING=$(curl $TIMEOUT -s "$API_BASE/is-playing" | jq -r '.is_playing // false')

        if [ "$IS_PLAYING" = "false" ]; then
            echo "--"
        else
            # Get current volume as percentage
            #shellcheck disable=SC2086
            VOLUME=$(curl $TIMEOUT -s "$API_BASE/volume" | jq -r '.volume // 0')
            # shellcheck disable=SC2046
            echo "$(printf "%.0f" $(echo "$VOLUME * 100" | bc -l))%"
        fi
    else
        # Check for increment/decrement syntax
        if [[ "$2" =~ ^([0-9]+)\+$ ]]; then
            # Increment: get current volume and add
            #shellcheck disable=SC2086
            CURRENT=$(curl $TIMEOUT -s "$API_BASE/volume" | jq -r '.volume // 0')
            # shellcheck disable=SC2046
            CURRENT_PCT=$(printf "%.0f" $(echo "$CURRENT * 100" | bc -l))
            INCREMENT=${BASH_REMATCH[1]}
            NEW_VOL=$((CURRENT_PCT + INCREMENT))
            # Cap at 100%
            [ "$NEW_VOL" -gt 100 ] && NEW_VOL=100
            echo "Volume: ${CURRENT_PCT}% → ${NEW_VOL}%"
        elif [[ "$2" =~ ^([0-9]+)\-$ ]]; then
            # Decrement: get current volume and subtract
            #shellcheck disable=SC2086
            CURRENT=$(curl $TIMEOUT -s "$API_BASE/volume" | jq -r '.volume // 0')
            # shellcheck disable=SC2046
            CURRENT_PCT=$(printf "%.0f" $(echo "$CURRENT * 100" | bc -l))
            DECREMENT=${BASH_REMATCH[1]}
            NEW_VOL=$((CURRENT_PCT - DECREMENT))
            # Floor at 1%
            [ $NEW_VOL -lt 1 ] && NEW_VOL=1
            echo "Volume: ${CURRENT_PCT}% → ${NEW_VOL}%"
        else
            # Absolute volume setting
            NEW_VOL=$2
            # Bounds check
            [ "$NEW_VOL" -gt 100 ] && NEW_VOL=100
            [ "$NEW_VOL" -lt 1 ] && NEW_VOL=1
            echo "Volume set to ${NEW_VOL}%"
        fi

        # Set the new volume
        # shellcheck disable=SC2046
        VOLUME_FLOAT=$(printf "%.2f" $(echo "scale=2; $NEW_VOL / 100" | bc -l))
        #shellcheck disable=SC2086
        curl $TIMEOUT -X POST -H "Content-Type: application/json" \
             -d "{\"volume\": $VOLUME_FLOAT}" "$API_BASE/volume" >/dev/null 2>&1
    fi
elif [ "$1" = "status" ]; then
    #shellcheck disable=SC2086
    curl $TIMEOUT -s "$API_BASE/now-playing" | jq -r '.info.name + " - " + .info.artistName'
else
    echo "Cider Music Control Script"
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  play playpause pause next previous prev - Playback controls"
    echo "  vol [n|n+|n-] - Set volume to n%, increment by n%, or decrement by n%"
    echo "  mute          - Mute audio (set volume to 0%)"
    echo "  status        - Show current track info"
    echo "  help          - Show this help message"
    echo ""
    echo "Volume examples:"
    echo "  $0 vol 50     - Set volume to 50%"
    echo "  $0 vol 10+    - Increase volume by 10%"
    echo "  $0 vol 5-     - Decrease volume by 5% (minimum 1%)"
    echo "  $0 vol        - Show current volume"
fi
