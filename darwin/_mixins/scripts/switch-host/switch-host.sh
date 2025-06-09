#!/usr/bin/env bash

if [ -e "${HOME}/Zero/nix-config/flake.nix" ]; then
    all_cores=$(sysctl -n hw.logicalcpu)
    build_cores=$(printf "%.0f" "$(echo "${all_cores} * 0.75" | bc)")
    echo "Switch nix-darwin 󰀵 with ${build_cores} cores"
    nh darwin switch "${HOME}/Zero/nix-config" -- --cores "${build_cores}"
else
    echo "ERROR! No nix-config found in ${HOME}/Zero/nix-config"
fi
