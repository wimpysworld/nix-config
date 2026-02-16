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
	echo "ERROR: No key name specified."
	echo "Usage: make-user-keys <key_name>"
	exit 1
fi
KEY="${1}"

SECRETS_FILE="${REPO_ROOT}/secrets/ssh.yaml"
if [[ ! -f "${SECRETS_FILE}" ]]; then
	echo "ERROR: Secrets file not found: ${SECRETS_FILE}"
	exit 1
fi

echo "Plug in your security key now, if you haven't already."
read -rp "Press Enter when ready to continue..."
echo ""

echo "Generating FIDO2/WebAuthn keys for ${KEY}..."

# Create temporary directory for key generation
tmpdir=$(mktemp -d)

# Generate ed25519-sk key pair (requires FIDO2 security key interaction)
ssh-keygen -t ed25519-sk -C "yubikey-${KEY}" -f "${tmpdir}/id_ed25519_sk_${KEY}"

if [[ ! -f "${tmpdir}/id_ed25519_sk_${KEY}" ]]; then
	echo "ERROR: Key generation failed. Please ensure your security key is connected."
	exit 1
fi

# JSON-encode the key files for sops
SK_KEY_JSON=$(jq -Rs . <"${tmpdir}/id_ed25519_sk_${KEY}")
SK_PUB_JSON=$(jq -Rs . <"${tmpdir}/id_ed25519_sk_${KEY}.pub")

echo "Adding keys to secrets/ssh.yaml..."

# Add keys to the secrets file using sops set
sops set "${SECRETS_FILE}" "[\"id_ed25519_sk_${KEY}\"]" "${SK_KEY_JSON}"
sops set "${SECRETS_FILE}" "[\"id_ed25519_sk_${KEY}_pub\"]" "${SK_PUB_JSON}"

echo ""
echo "✓ FIDO2/WebAuthn keys added to secrets/ssh.yaml"
echo ""
echo "Keys added:"
echo "  - id_ed25519_sk_${KEY}"
echo "  - id_ed25519_sk_${KEY}_pub"
echo ""
echo "Next steps:"
echo ""
echo "1. Add the key basename to the ed25519SkKeyIdentifiers list:"
echo "    home-manager/_mixins/users/martin/ssh.nix"
echo ""
echo "2. Add the public key to GitHub and configure SSO:"
echo "    https://github.com/settings/keys"
echo ""
echo "3. Switch Home Manager:"
echo "    just home"
echo ""
echo "4. Add the key to the SSH agent (requires the key passphrase):"
echo "    ssh-add ~/.ssh/id_ed25519_sk_${KEY}"
echo ""
echo "5. List the keys to verify:"
echo "    ssh-add -L"
echo ""
echo "6. Run the following, if you haven't already:"
echo "    gh auth login -p ssh"
