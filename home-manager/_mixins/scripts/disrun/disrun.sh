#!/usr/bin/env bash

# Function to display usage
function usage() {
    echo "Usage: $(basename "${0}") <program> [args...]"
    exit 1
}

# Check if the correct number of arguments is provided
if [ $# -lt 1 ]; then
    usage
fi

# Get the program to execute from the first argument
PROGRAM="${1}"
shift

# Check if the program is in the PATH
if ! command -v "${PROGRAM}" &> /dev/null; then
    echo "${PROGRAM}: is not in the PATH."
    exit 1
fi

# Execute the program with all remaining arguments and capture its PID
"${PROGRAM}" "$@" &
PID=$!

# Verify the PID is running
if kill -0 "${PID}" &> /dev/null; then
    disown ${PID}
    echo "${PROGRAM}: disowned ${PID}."
else
    echo "${PROGRAM}: process ${PID} is not running."
    exit 1
fi
