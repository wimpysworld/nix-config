#!/usr/bin/env bash

rhythmbox-client --no-start --pause
rhythmbox-client --no-start --no-repeat
rhythmbox-client --no-start --no-shuffle
rhythmbox-client --no-start --set-volume 0

# Restore PipeWire Quantum
pw-metadata --name settings 0 clock.force-quantum 0

# Disable sidetone
mic-loopback set 100
mic-loopback off
