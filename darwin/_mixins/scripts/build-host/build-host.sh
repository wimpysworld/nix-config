#!/usr/bin/env bash

HOST=$(hostname)
if [ -e ~/Zero/nix-config ]; then
    all_cores=$(nproc)
    build_cores=$(printf "%.0f" "$(echo "${all_cores} * 0.75" | bc)")
    echo "Building nix-darwin ❄️ with ${build_cores} cores"
    pushd ~/Zero/nix-config
    nom build ".#darwinConfigurations.${HOST}.config.system.build.toplevel" --cores "${build_cores}"
    popd
else
    echo "ERROR! No nix-config found in ~/Zero/nix-config"
fi
