#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset
set +o pipefail  # Disable pipefail

HOST="$(hostname -s)"
if [ -d "$HOME/Vaults/Secrets/ssh" ]; then
    echo "Backing up SSH host keys for $HOST to the vault..."
    sudo true
    sudo rsync -v --chown="$USER":users /run/secrets/ssh_host_* "$HOME"/.cache/
    mkdir -p "$HOME/Vaults/Secrets/ssh/$HOST/" 2>/dev/null
    mv -v "$HOME"/.cache/ssh_host_* "$HOME/Vaults/Secrets/ssh/$HOST/"
else
  echo "ERROR: The Secrets vault is not mounted."
  exit 1
fi
