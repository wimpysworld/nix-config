#!/usr/bin/env bash

if [ -e "${HOME}/Zero/nix-config" ]; then
    all_cores=$(nproc)
    build_cores=$(printf "%.0f" "$(echo "${all_cores} * 0.75" | bc)")
    echo "Switch nix-darwin ❄️ with ${build_cores} cores"
    nix run nix-darwin -- switch --flake "${HOME}/Zero/nix-config" --cores "${build_cores}" -L
else
    echo "ERROR! No nix-config found in ${HOME}/Zero/nix-config"
fi
