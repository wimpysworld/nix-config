#!/usr/bin/env bash

# Build home-manager, using the best available command
if command -v nh-home &> /dev/null; then
    nh-home build
elif command -v nh &> /dev/null; then
    nh home build "${HOME}/Zero/nix-config/"
elif command -v home-manager &> /dev/null; then
    home-manager build --flake "$HOME/Zero/nix-config" -L
else
    nix run nixpkgs#home-manager -- build "$HOME/Zero/nix-config" -L
fi
build-host
