#!/usr/bin/env bash

HOST=""
NAME=""

if [ -n "${1}" ]; then
  HOST="${1}"
else
  echo "ERROR! $(basename "${0}") requires a host name:"
  ls -1 host/ | grep -v ".nix" | grep -v _
  exit 1
fi

case "${HOST}" in
  designare) true;;
  *)
    echo "ERROR! ${HOST} is not a supported host"
    exit 1
    ;;
esac

if [ -n "${2}" ]; then
  NAME="${2}"
else
  echo "ERROR! $(basename "${0}") requires a user name"
  ls -1 host/_mixins/users | grep -v root
  exit 1
fi

case "${NAME}" in
  martin) true;;
  *)
    echo "ERROR! ${NAME} is not a supported user"
    exit 1
    ;;
esac

if [ ! -e "host/${HOST}/disks.nix" ]; then
  echo "ERROR! $(basename "${0}") could not find the required host/${HOST}/disks.nix"
  exit 1
fi

if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR! $(basename "${0}") should be run as a regular user"
  exit 1
fi

echo "WARNING! The disks in ${HOST} are about to get wiped"
echo "         NixOS will be re-installed"
echo "         This is a destructive operation"
echo
read -p "Are you sure? [y/N]" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo true
    sudo nix run github:nix-community/disko --extra-experimental-features 'nix-command flakes' --no-write-lock-file -- --mode zap_create_mount "host/${HOST}/disks.nix"
    sudo nixos-install --no-root-password --flake .#${HOST}
    env HOME=/mnt/home/"${NAME}" home-manager --extra-experimental-features 'nix-command flakes' switch -b backup --flake .#${NAME}@${HOST}

    # Copy the nix-config to the new system
    mkdir -p /mnt/home/"${NAME}"/Zero/nix-config
    cp -a ./. /mnt/home/"${NAME}"/Zero/nix-config/
fi
