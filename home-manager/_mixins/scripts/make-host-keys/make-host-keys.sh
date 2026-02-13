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
	echo "Usage: make-host-keys <hostname>"
	exit 1
fi
HOSTNAME="${1}"

SECRETS_FILE="${REPO_ROOT}/secrets/${HOSTNAME}.yaml"
if [[ ! -f "${SECRETS_FILE}" ]]; then
	echo "Secrets file not found; creating secrets/${HOSTNAME}.yaml..."
	echo '{}' >"${SECRETS_FILE}"
	sops encrypt -i "${SECRETS_FILE}"
fi

echo "Generating SSH host keys for ${HOSTNAME}..."

# Create temporary directory for key generation
tmpdir=$(mktemp -d)

# Generate SSH host keys
ssh-keygen -N "" -C "root@${HOSTNAME}" -t ed25519 -f "${tmpdir}/ssh_host_ed25519_key" >/dev/null 2>&1
ssh-keygen -N "" -C "root@${HOSTNAME}" -t rsa -b 4096 -f "${tmpdir}/ssh_host_rsa_key" >/dev/null 2>&1

# JSON-encode the key files for sops
ED25519_KEY_JSON=$(jq -Rs . <"${tmpdir}/ssh_host_ed25519_key")
ED25519_PUB_JSON=$(jq -Rs . <"${tmpdir}/ssh_host_ed25519_key.pub")
RSA_KEY_JSON=$(jq -Rs . <"${tmpdir}/ssh_host_rsa_key")
RSA_PUB_JSON=$(jq -Rs . <"${tmpdir}/ssh_host_rsa_key.pub")

echo "Adding keys to secrets/${HOSTNAME}.yaml..."

# Add keys to the secrets file using sops set
sops set "${SECRETS_FILE}" '["ssh_host_ed25519_key"]' "${ED25519_KEY_JSON}"
sops set "${SECRETS_FILE}" '["ssh_host_ed25519_key_pub"]' "${ED25519_PUB_JSON}"
sops set "${SECRETS_FILE}" '["ssh_host_rsa_key"]' "${RSA_KEY_JSON}"
sops set "${SECRETS_FILE}" '["ssh_host_rsa_key_pub"]' "${RSA_PUB_JSON}"

echo ""
echo "✓ SSH host keys added to secrets/${HOSTNAME}.yaml"
echo ""
echo "Keys added:"
echo "  - ssh_host_ed25519_key"
echo "  - ssh_host_ed25519_key_pub"
echo "  - ssh_host_rsa_key"
echo "  - ssh_host_rsa_key_pub"
