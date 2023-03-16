#!/usr/bin/env bash

HOST="$(basename ${0} .sh)"

if [ ! -e "host/${HOST}/disks.nix" ]; then
  echo "🛑 ERROR! $(basename ${0}) could not find the required host/${HOST}/disks.nix"
  exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "🛑 ERROR! $(basename ${0}) requires root permissions"
  exit 1
fi

echo "⚠️  WARNING! The disks in ${HOST} are about to get wiped"
echo "❄️  NixOS will be re-installed"
echo "🚨  This is a destructive operation"
echo
read -p "🤔  Are you sure? [y/N]" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    nix run github:nix-community/disko --extra-experimental-features 'flakes nix-command' --no-write-lock-file -- --mode zap_create_mount "host/${HOST}/disks.nix"
    nixos-install --no-root-password --flake .#${HOST}

    # Copy the nix-config to the new system
    # TODO: This is a hack, find a better way to do this
    mkdir -p /mnt/home/martin/Zero/nix-config
    cp -a ./. /mnt/home/martin/Zero/nix-config/
    chown -R 1000:100 /mnt/home/martin/Zero/nix-config
fi
