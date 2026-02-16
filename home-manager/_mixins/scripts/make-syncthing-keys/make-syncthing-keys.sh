#!/usr/bin/env bash

set -euo pipefail

# Locate the nix-config repository root
REPO_ROOT="${HOME}/Zero/nix-config"

# Cleanup function for temporary directory
cleanup() {
	if [[ -n "${tmpdir:-}" && -d "${tmpdir}" ]]; then
		rm -rf "${tmpdir}"
	fi
}
trap cleanup EXIT

if [[ -z "${1:-}" ]]; then
	echo "ERROR: No hostname specified."
	echo "Usage: make-syncthing-keys <hostname>"
	exit 1
fi
HOSTNAME="${1}"

SECRETS_FILE="${REPO_ROOT}/secrets/host-${HOSTNAME}.yaml"
if [[ ! -f "${SECRETS_FILE}" ]]; then
	echo "ERROR: Secrets file not found: ${SECRETS_FILE}"
	exit 1
fi

echo "Generating Syncthing keys for ${HOSTNAME}..."

# Create temporary directory for key generation
tmpdir=$(mktemp -d)

# Generate Syncthing keys
syncthing generate --home="${tmpdir}" >/dev/null 2>&1

# Extract device ID
DEVICE_ID=$(syncthing device-id --home="${tmpdir}")

# JSON-encode the key and certificate files for sops
KEY_JSON=$(jq -Rs . <"${tmpdir}/key.pem")
CERT_JSON=$(jq -Rs . <"${tmpdir}/cert.pem")

echo "Adding keys to secrets/host-${HOSTNAME}.yaml..."

# Add keys to the secrets file using sops set
sops set "${SECRETS_FILE}" '["syncthing_key"]' "${KEY_JSON}"
sops set "${SECRETS_FILE}" '["syncthing_cert"]' "${CERT_JSON}"

echo ""
echo "✓ Keys added to secrets/host-${HOSTNAME}.yaml"
echo ""
echo "Device ID: ${DEVICE_ID}"
echo ""
echo "Update syncthing-devices.nix with the new device ID."
