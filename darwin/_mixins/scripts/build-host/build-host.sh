#!/usr/bin/env bash

export NH_NO_CHECKS=1

if [ -e "${HOME}/Zero/nix-config/flake.nix" ]; then
    all_cores=$(nproc)
    build_cores=$(printf "%.0f" "$(echo "${all_cores} * 0.75" | bc)")
    echo "Building nix-darwin 󰀵 with ${build_cores} cores"
    nh darwin build "${HOME}/Zero/nix-config" -- --cores "${build_cores}"
else
    echo "ERROR! No nix-config found in ~/Zero/nix-config"
fi
