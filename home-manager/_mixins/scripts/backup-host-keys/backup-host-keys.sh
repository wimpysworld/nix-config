#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset
set +o pipefail  # Disable pipefail

HOST="$(hostname -s)"
if [ -d "$HOME/Keybase/private/wimpress/Secrets/ssh" ]; then
    echo "Backing up SSH host keys for $HOST to Keybase..."
    sudo true
    sudo rsync -v --chown="$USER":users /etc/ssh/ssh_host_* "$HOME"/.cache/
    mkdir -p "$HOME/Keybase/private/wimpress/Secrets/ssh/$HOST/" 2>/dev/null
    mv -v "$HOME"/.cache/ssh_host_* "$HOME/Keybase/private/wimpress/Secrets/ssh/$HOST/"
else
  echo "ERROR: Keybase not mounted"
  exit 1
fi
