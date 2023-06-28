#!/usr/bin/env bash

set -euo pipefail
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

TARGET_HOST="${1:-}"
TARGET_USER="${2:-martin}"

if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR! $(basename "${0}") should be run as a regular user"
  exit 1
fi

if [ -z "${TARGET_HOST}" ]; then
  echo "ERROR! $(basename "${0}") requires a hostname as the first argument"
  exit 1
fi

if [ ! -e "nixos/${TARGET_HOST}/disks.nix" ]; then
  echo "ERROR! $(basename "${0}") could not find the required nixos/${TARGET_HOST}/disks.nix"
  exit 1
fi

# Check if the machine we're provisioning expects a keyfile to unlock a disk.
# If it does, generate a new key, and write to a known location.
if grep -q "data.keyfile" "host/${TARGET_HOST}/disks.nix"; then
  echo -n "$(head -c32 /dev/random | base64)" > /tmp/data.keyfile
fi

echo "WARNING! The disks in ${TARGET_HOST} are about to get wiped"
echo "         NixOS will be re-installed"
echo "         This is a destructive operation"
echo
read -p "Are you sure? [y/N]" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  sudo true

  # Fudge the per-user profile directories so home-manager hacks later on work
  #if [ ! -d "/nix/var/nix/profiles/per-user/${TARGET_USER}" ]; then
  #  sudo mv /nix/var/nix/profiles/per-user/nixos "/nix/var/nix/profiles/per-user/${TARGET_USER}"
  #  pushd /nix/var/nix/profiles/per-user
  #  sudo ln -s "${TARGET_USER}" nixos
  #  popd
  #fi

  sudo nix run github:nix-community/disko \
    --extra-experimental-features "nix-command flakes" \
    --no-write-lock-file \
    -- \
    --mode zap_create_mount \
    "nixos/${TARGET_HOST}/disks.nix"

  sudo nixos-install --no-root-password --flake ".#${TARGET_HOST}"

  # Create directories required by Home Manager
  #sudo mkdir -p "/nix/var/nix/profiles/per-user/${TARGET_USER}"
  #sudo chown -R 1000:root "/nix/var/nix/profiles/per-user/${TARGET_USER}"
  #sudo mkdir -p "/home/${TARGET_USER}"
  #sudo chown -R 1000:1000 "/home/${TARGET_USER}"
  # Deploy home-manager config
  #env USER="${TARGET_USER}" HOME="/mnt/home/${TARGET_USER}" home-manager --extra-experimental-features 'nix-command flakes' switch -b backup --flake ".#${TARGET_USER}@${TARGET_HOST}"
  # Hacky McHack Face
  #sudo rsync -a --delete "/nix/var/nix/profiles/per-user/${TARGET_USER}/" "/mnt/nix/var/nix/profiles/per-user/${TARGET_USER}/"
  #sudo rsync -av "/nix/store/" "/mnt/nix/store/"

  # Rsync my nix-config to the target install
  mkdir -p "/mnt/home/${TARGET_USER}/Zero/nix-config"
  rsync -a --delete "${DIR}/.." "/mnt/home/${TARGET_USER}/Zero/nix-config/"

  # If there is a keyfile for a data disk, put copy it to the root partition and
  # ensure the permissions are set appropriately.
  if [[ -f "/tmp/data.keyfile" ]]; then
    sudo cp /tmp/data.keyfile /mnt/etc/data.keyfile
    sudo chmod 0400 /mnt/etc/data.keyfile
  fi

  # Re-point the per-user profile directory to the correct location
  #pushd "/mnt/home/${TARGET_USER}"
  #rm -f .nix-profile
  #ln -s "/nix/var/nix/profiles/per-user/${TARGET_USER}/profile" .nix-profile
  #popd
fi
