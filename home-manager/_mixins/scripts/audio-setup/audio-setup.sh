#!/usr/bin/env bash

set +o pipefail  # Disable pipefail

# Enable sidetone
mic-loopback on
mic-loopback set 120

# Pause all audio players
playerctl -p sidra pause || true
playerctl -p Lodge_iPad pause || true

rhythmbox-client --no-start --set-volume 0
rhythmbox-client --no-start --pause
rhythmbox-client --no-start --shuffle
rhythmbox-client --no-start --repeat
