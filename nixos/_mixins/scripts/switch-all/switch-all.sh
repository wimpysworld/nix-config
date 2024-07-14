#!/usr/bin/env bash

for BUILDER in switch-home switch-host; do
    # if BUILDER is in the PATH, run it
    if command -v "${BUILDER}" &> /dev/null; then
        "${BUILDER}"
    else
        echo "WARNING! ${BUILDER} not found."
    fi
done
