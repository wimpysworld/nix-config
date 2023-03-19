#!/usr/bin/env bash

TARGET_HOST=""
TARGET_USER=""

if [ -n "${1}" ]; then
  TARGET_HOST="${1}"
else
  echo "ERROR! $(basename "${0}") requires a host name:"
  ls -1 host/ | grep -v ".nix" | grep -v _
  exit 1
fi

case "${TARGET_HOST}" in
  designare*|vm) true;;
  *)
    echo "ERROR! ${TARGET_HOST} is not a supported host"
    exit 1
    ;;
esac

if [ -n "${2}" ]; then
  TARGET_USER="${2}"
else
  echo "ERROR! $(basename "${0}") requires a user name"
  ls -1 host/_mixins/users | grep -v root
  exit 1
fi

case "${TARGET_USER}" in
  martin) true;;
  *)
    echo "ERROR! ${TARGET_USER} is not a supported user"
    exit 1
    ;;
esac

if [ ! -e "host/${TARGET_HOST}/disks.nix" ]; then
  echo "ERROR! $(basename "${0}") could not find the required host/${TARGET_HOST}/disks.nix"
  exit 1
fi

if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR! $(basename "${0}") should be run as a regular user"
  exit 1
fi

echo "WARNING! The disks in ${TARGET_HOST} are about to get wiped"
echo "         NixOS will be re-installed"
echo "         This is a destructive operation"
echo
read -p "Are you sure? [y/N]" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo true
    sudo nix run github:nix-community/disko --extra-experimental-features 'nix-command flakes' --no-write-lock-file -- --mode zap_create_mount "host/${TARGET_HOST}/disks.nix"
    sudo nixos-install --no-root-password --flake ".#${TARGET_HOST}"

    # Create directories required by Home Manager
    sudo mkdir -p "/nix/var/nix/profiles/per-user/${TARGET_USER}"
    sudo chown -R 1000:root "/nix/var/nix/profiles/per-user/${TARGET_USER}"
    sudo mkdir -p "/home/${TARGET_USER}"
    sudo chown -R 1000:1000 "/home/${TARGET_USER}"
    # Deploy home-manager config
    env USER="${TARGET_USER}" HOME="/mnt/home/${TARGET_USER}" home-manager --extra-experimental-features 'nix-command flakes' switch -b backup --flake ".#${TARGET_USER}@${TARGET_HOST}"

    # Rsync my nix-config to the target install
    mkdir -p "/mnt/home/${TARGET_USER}/Zero/nix-config"
    rsync -a --delete "${PWD}/" "/mnt/home/${TARGET_USER}/Zero/nix-config/"
fi
