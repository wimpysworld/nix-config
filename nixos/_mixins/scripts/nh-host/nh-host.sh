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

if [ -e "${HOME}/Zero/nix-config" ]; then
    all_cores=$(nproc)
    build_cores=$(printf "%.0f" "$(echo "${all_cores} * 0.75" | bc)")
    echo "${1^}ing NixOS  with ${build_cores} cores"
    nh os "${1}" "${HOME}/Zero/nix-config/" -- --cores "${build_cores}"
else
    echo "ERROR! No nix-config found in ${HOME}/Zero/nix-config"
fi
