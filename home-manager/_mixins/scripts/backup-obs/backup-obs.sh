#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset
set +o pipefail  # Disable pipefail

HOST="$(hostnamectl hostname)"
STAMP="$(date +%y%m%d-%H%M)"
echo "Backing up OBS Studio"
IFS=$'\n'

echo -e "  - ${OBS}:\tBacking up ${STAMP}-${HOST}"
if [ -d "${HOME}/Studio/OBS/config" ]; then
    mkdir -p "${HOME}/Studio/Backups/OBS/${STAMP}-${HOST}/system"
    rsync -a "${HOME}/Studio/OBS/config/" "${HOME}/Studio/Backups/OBS/${STAMP}-${HOST}/system/config/"
fi

# shellcheck disable=2045
for OBS in $(ls -1 "${HOME}/Studio/OBS/"); do
  if [ -x "${HOME}/Studio/OBS/${OBS}/bin/64bit/obs" ] && [ -d "${HOME}/Studio/OBS/${OBS}/config/" ]; then
    mkdir -p "${HOME}/Studio/Backups/OBS/${STAMP}-${HOST}/${OBS}"
    rsync -a "${HOME}/Studio/OBS/${OBS}/config/" "${HOME}/Studio/Backups/OBS/${STAMP}-${HOST}/${OBS}/config/"
  fi
done
