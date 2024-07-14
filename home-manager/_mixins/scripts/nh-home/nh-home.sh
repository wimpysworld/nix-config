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

# Proceed if the nix-config directory exists
if [ -e "${HOME}/Zero/nix-config" ]; then
    # Get the number of processing units
    all_cores=$(nproc)
    # Calculate 75% of the number of processing units
    build_cores=$(printf "%.0f" "$(echo "${all_cores} * 0.75" | bc)")

    echo "${1^}ing Home Manager 🏠️ with ${build_cores} cores"
    case $1 in
        build) nh home build "${HOME}/Zero/nix-config/" -- --cores "${build_cores}";;
        switch) nh home switch --backup-extension backup "${HOME}/Zero/nix-config/" -- --cores "${build_cores}";;
    esac
else
    echo "ERROR! No nix-config found in ${HOME}/Zero/nix-config"
fi
