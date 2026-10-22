#!/usr/bin/env bash

# Enrol this device with Swif.ai. Runs once, from swif-agent-installer.service.
# Identity values come from systemd credentials, not from the Nix store.

INSTALL_FLAG="/var/lib/swifteam/installed.flag"

if [[ -f "${INSTALL_FLAG}" ]]; then
	echo "[swif-install] Already installed. Skipping."
	exit 0
fi

if [[ -z "${CREDENTIALS_DIRECTORY:-}" ]]; then
	echo "[swif-install] CREDENTIALS_DIRECTORY is not set." >&2
	exit 1
fi

for name in swif-teamid swif-firstname swif-surname swif-email; do
	if [[ ! -s "${CREDENTIALS_DIRECTORY}/${name}" ]]; then
		echo "[swif-install] Credential ${name} is missing or empty." >&2
		exit 1
	fi
done

read_credential() {
	tr -d '\r\n' <"${CREDENTIALS_DIRECTORY}/$1"
}

# The flag is written only after the installer succeeds, so a failed run
# retries at the next boot.
echo "[swif-install] Running installer ..."
SwifInstaller \
	-teamId="$(read_credential swif-teamid)" \
	-name="$(read_credential swif-firstname)" \
	-surname="$(read_credential swif-surname)" \
	-email="$(read_credential swif-email)" \
	-nixRootPath="${SWIF_NIX_ROOT_PATH}"

touch "${INSTALL_FLAG}"
echo "[swif-install] Done."
