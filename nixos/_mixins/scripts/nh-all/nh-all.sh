#!/usr/bin/env bash

function usage() {
    echo "Usage: ${0} {build|switch}"
    exit 1
}

# Validate input argument
if [ "$#" -ne 1 ]; then
    usage
fi

if [ "${1}" != "build" ] && [ "${1}" != "switch" ]; then
    echo "Invalid argument: ${1}"
    usage
fi

for BUILDER in nh-home nh-host; do
    # if BUILDER is in the PATH, run it
    if command -v "${BUILDER}" &> /dev/null; then
        "${BUILDER}" "${1}"
    else
        echo "WARNING! ${BUILDER} not found."
    fi
done
