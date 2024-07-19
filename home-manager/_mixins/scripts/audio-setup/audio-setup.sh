#!/usr/bin/env bash

set +o pipefail  # Disable pipefail

HOST=$(hostnamectl hostname)

# Enable sidetone
mic-loopback on
mic-loopback set 120

# Optimise PipeWire Quantum for OBS Studio; prevent audio crackling
case "${HOST}" in
    vader)  pw-metadata --name settings 0 clock.force-quantum 64;;
    phasma) pw-metadata --name settings 0 clock.force-quantum 64;;
    *) pw-metadata --name settings 0 clock.force-quantum 1024;;
esac

# Pause all audio players
playerctl -p cider pause || true
playerctl -p Lodge_iPad pause || true

rhythmbox-client --no-start --set-volume 0
rhythmbox-client --no-start --pause
rhythmbox-client --no-start --shuffle
rhythmbox-client --no-start --repeat
