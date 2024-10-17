#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset
set +o pipefail  # Disable pipefail

if [ -z "${1}" ]; then
    echo "Usage: $(basename "${0}") <remote-host>"
    exit 1
fi

REMOTE_HOST="${1}"

if [ -e "$HOME"/Zero/nix-config/pkgs/cider/Cider-linux-appimage-x64.AppImage ] && \
   [ -e "$HOME"/Zero/nix-config/pkgs/pico8/pico-8_0.2.6b_amd64.zip ]; then
    echo "Cider and PICO-8 files found"
else
    echo "Cider and PICO-8 files not found"
    exit 1
fi

echo "Sending Cider to ${REMOTE_HOST}"
rsync -a --info=progress2 "$HOME/Zero/nix-config/pkgs/cider/Cider-linux-appimage-x64.AppImage" "${USER}@${REMOTE_HOST}:Zero/nix-config/pkgs/cider/"
ssh "${REMOTE_HOST}" nix-store --add-fixed sha256 "$HOME/Zero/nix-config/pkgs/cider/Cider-linux-appimage-x64.AppImage"
echo "Sending PICO-8 to ${REMOTE_HOST}"
rsync -a --info=progress2 "$HOME/Zero/nix-config/pkgs/pico8/pico-8_0.2.6b_amd64.zip" "${USER}@${REMOTE_HOST}:Zero/nix-config/pkgs/pico8/"
ssh "${REMOTE_HOST}" nix-store --add-fixed sha256 "$HOME/Zero/nix-config/pkgs/pico8/pico-8_0.2.6b_amd64.zip"
