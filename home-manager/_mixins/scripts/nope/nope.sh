#!/usr/bin/env bash

# Exit on error, undefined variable, and error in pipes
set -euo pipefail

# Function to display usage
function usage() {
    echo "Usage: $(basename "${0}") <program> [args...]"
    echo "Launch a program detached from the current session"
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

# Use setsid to run the program in a new session, fully detached
setsid --fork "${PROGRAM}" "$@" &>/dev/null
