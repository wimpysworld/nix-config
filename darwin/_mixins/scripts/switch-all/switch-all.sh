#!/usr/bin/env bash

# if nh-home is in the PATH then use it
if command -v nh-home &> /dev/null; then
    nh-home build
else
    nix run nixpkgs#home-manager -- switch --flake "$HOME/Zero/nix-config" -L
fi
switch-host
