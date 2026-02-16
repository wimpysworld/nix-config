#!/usr/bin/env bash

# Synchronise Steam save data from chimeraos to local backup directory.
# Uses incremental hardlink backups with timestamped directories.
#
# Usage: sync-steam-saves <game-name> <remote-source-path>
#   game-name:          Short identifier for the game (e.g. "legoworlds")
#   remote-source-path: Path on the remote host relative to home (e.g. ".local/share/Steam/...")

if [ "$#" -ne 2 ]; then
	echo "Usage: sync-steam-saves <game-name> <remote-source-path>"
	exit 1
fi

GAME_NAME="$1"
REMOTE_PATH="$2"

IP="chimeraos"
REMOTE_USER="gamer"
NOW=$(date +%y.%j.%H%M)
SOURCE="${REMOTE_USER}@${IP}:${REMOTE_PATH}"
TARGET="${HOME}/Games/Steam_Backups/${GAME_NAME}"
BACKUP_NOW="${TARGET}/${NOW}"
mkdir -p "${TARGET}"

if ! nc -z "${IP}" 22 2>/dev/null; then
	# Remote host is offline; nothing to do.
	exit 0
fi

echo "${IP} is online"

if ls -1dr "${TARGET}/"* >/dev/null 2>&1; then
	BACKUP_PREV=$(ls -1dr "${TARGET}/"* | head -n1)
	if [ "${BACKUP_NOW}" == "${BACKUP_PREV}" ]; then
		echo " - ERROR! Backup target is the same as previous backup, skipping."
		exit 1
	elif [ -d "${BACKUP_PREV}" ]; then
		echo " - Incremental from: ${BACKUP_PREV}"
		rsync -a --human-readable --info=progress2 --protect-args --link-dest "${BACKUP_PREV}/" "${SOURCE}" "${BACKUP_NOW}/"
	else
		echo " - ERROR! Last backup not found"
		exit 1
	fi
else
	echo " - No backups, creating first backup"
	rsync -a --human-readable --info=progress2 --protect-args "${SOURCE}" "${BACKUP_NOW}/"
fi

notify-desktop "Steam Backup" "${GAME_NAME} backup completed"
