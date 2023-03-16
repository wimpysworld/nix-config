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

echo "⚠️  WARNING! The disks in ${HOST}) are about to get wiped"
read -p "Are you sure? [y/N]" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    #nix run github:nix-community/disko --no-write-lock-file -- -m zap_create_mount --dry-run "host/${HOST}/disks.nix"
    nix run github:nix-community/disko --no-write-lock-file -- --mode zap_create_mount "host/${HOST}/disks.nix"
fi
