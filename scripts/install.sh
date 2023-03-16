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

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR! $(basename "${0}") requires root permissions"
  exit 1
fi

echo "WARNING! The disks in ${HOST} are about to get wiped"
echo "         NixOS will be re-installed"
echo "         This is a destructive operation"
echo
read -p "Are you sure? [y/N]" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    nix run github:nix-community/disko --extra-experimental-features 'flakes nix-command' --no-write-lock-file -- --mode zap_create_mount "host/${HOST}/disks.nix"
    nixos-install --no-root-password --flake .#${HOST}
    home-manager switch -b backup --flake .#${NAME}

    # Copy the nix-config to the new system
    mkdir -p /mnt/home/"${USER}"/Zero/nix-config
    cp -a ./. /mnt/home/"${USER}"/Zero/nix-config/
    chown -R 1000:100 /mnt/home/"${USER}"/Zero/nix-config
fi
