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
	echo "Usage: make-luks-key <hostname>"
	exit 1
fi
HOSTNAME="${1}"

SECRETS_FILE="${REPO_ROOT}/secrets/host-${HOSTNAME}.yaml"
if [[ ! -f "${SECRETS_FILE}" ]]; then
	echo "Secrets file not found; creating secrets/host-${HOSTNAME}.yaml..."
	echo '{}' >"${SECRETS_FILE}"
	sops encrypt -i "${SECRETS_FILE}"
fi

echo "Generating LUKS key for ${HOSTNAME}..."

# Create temporary directory for key generation
tmpdir=$(mktemp -d)

# Generate a 4096-byte random LUKS key
dd if=/dev/urandom of="${tmpdir}/luks.key" bs=4096 count=1 iflag=fullblock 2>/dev/null

# JSON-encode the key file for sops
LUKS_KEY_JSON=$(jq -Rs . <"${tmpdir}/luks.key")

echo "Adding LUKS key to secrets/host-${HOSTNAME}.yaml..."

# Add the key to the secrets file using sops set
sops set "${SECRETS_FILE}" '["luks_key"]' "${LUKS_KEY_JSON}"

echo ""
echo "✓ LUKS key added to secrets/host-${HOSTNAME}.yaml"
echo ""
echo "Keys added:"
echo "  - luks_key"
