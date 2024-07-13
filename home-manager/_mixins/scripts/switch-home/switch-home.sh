#!/usr/bin/env bash
if [ -e "${HOME}/Zero/nix-config" ]; then
    # Get the number of processing units
    all_cores=$(nproc)
    # Calculate 75% of the number of processing units
    build_cores=$(echo "scale=0; 0.75 * ${all_cores} / 1" | bc)
    echo "Switch Home Manager with ${build_cores} cores"
    nh home switch --backup-extension backup "${HOME}/Zero/nix-config/" -- --cores "${build_cores}"
else
    echo "ERROR! No nix-config found in ${HOME}/Zero/nix-config"
fi
