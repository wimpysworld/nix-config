#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset
set +o pipefail  # Disable pipefail

if [ -z "${1}" ]; then
    echo "ERROR: No host specified."
    exit 1
fi
HOST="${1}"

if [ -d "$HOME/Vaults/Secrets/luks" ]; then
  echo "Creating LUKS keys for $HOST..."
  if [ ! -e "$HOME/Vaults/Secrets/luks/$HOST.key" ]; then
    dd if=/dev/urandom of="$HOME/Vaults/Secrets/luks/$HOST.key" bs=4096 count=1 iflag=fullblock
    chmod 600 "$HOME/Vaults/Secrets/luks/$HOST.key"
    echo "LUKS key for $HOST created successfully."
  else
    echo "LUKS key for $HOST already exists."
  fi
else
  echo "ERROR: The Secrets vault is not mounted."
  exit 1
fi

