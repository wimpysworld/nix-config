#!/usr/bin/env bash

export NH_NO_CHECKS=1
STAMP=$(date +%Y%m%d-%H%M%S)

# Switch home-manager, using the best available command
if command -v nh-home &> /dev/null; then
    nh-home switch
elif command -v nh &> /dev/null; then
    nh home switch --backup-extension "${STAMP}" "${HOME}/Zero/nix-config/"
elif command -v home-manager &> /dev/null; then
    home-manager switch --backup-extension "${STAMP}" --flake "$HOME/Zero/nix-config" -L
else
    nix run nixpkgs#home-manager -- switch --backup-extension "${STAMP}" --flake "$HOME/Zero/nix-config" -L
fi
switch-host
