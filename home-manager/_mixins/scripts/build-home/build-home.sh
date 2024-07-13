#!/usr/bin/env bash
if [ -e "${HOME}/Zero/nix-config" ]; then
    # Get the number of processing units
    all_cores=$(nproc)
    # Calculate 75% of the number of processing units
    build_cores=$(printf "%.0f" "$(echo "${all_cores} * 0.75" | bc)")
    echo "Building Home Manager with ${build_cores} cores"
    nh home build --backup-extension backup "${HOME}/Zero/nix-config/" -- --cores "${build_cores}"
else
    echo "ERROR! No nix-config found in ${HOME}/Zero/nix-config"
fi
