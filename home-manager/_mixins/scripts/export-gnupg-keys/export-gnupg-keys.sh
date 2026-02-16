#!/usr/bin/env bash

set -euo pipefail

# Export all GPG keys (public and private) to sops-encrypted secrets/gnupg.yaml
# and write public key .asc files to the repository for use with programs.gpg.publicKeys.

# Locate the nix-config repository root.
REPO_ROOT="${HOME}/Zero/nix-config"

# Cleanup function for temporary directory.
cleanup() {
	if [[ -n "${tmpdir:-}" && -d "${tmpdir}" ]]; then
		rm -rf "${tmpdir}"
	fi
}
trap cleanup EXIT

# All three master key fingerprints, in order of creation.
FINGERPRINTS=(
	"5E7585ADFF106BFFBBA319DC654B877A0864983E"
	"79F9461BF24B27F50DEB8A507454357CFFEE1E5C"
	"8F04688C17006782143279DA61DF940515E06DA3"
)

SECRETS_FILE="${REPO_ROOT}/secrets/gnupg.yaml"
PUBKEY_DIR="${REPO_ROOT}/home-manager/_mixins/users/martin"

# Create temporary directory for key exports.
tmpdir=$(mktemp -d)

# Initialise the sops file if it does not already exist.
# sops set requires an existing encrypted file with sops metadata, so we
# bootstrap one by encrypting a placeholder YAML document. An empty document
# ({}) produces a 0-byte file with no metadata, so we use a dummy key instead.
# --filename-override tells sops to match creation_rules against the target
# path rather than /dev/stdin.
if [[ ! -f "${SECRETS_FILE}" ]] || [[ ! -s "${SECRETS_FILE}" ]]; then
	echo "Initialising ${SECRETS_FILE}..."
	sops_init="${tmpdir}/sops-init.yaml"
	echo "placeholder: init" | sops encrypt --filename-override "${SECRETS_FILE}" --input-type yaml --output-type yaml /dev/stdin >"${sops_init}"
	mv "${sops_init}" "${SECRETS_FILE}"
fi

for FP in "${FINGERPRINTS[@]}"; do
	# Derive the short ID (last 8 hex characters of the fingerprint).
	SHORT_ID="${FP: -8}"

	echo "Exporting key ${SHORT_ID} (${FP})..."

	# Export public key to a temporary file.
	PUB_FILE="${tmpdir}/pub-${SHORT_ID}.asc"
	gpg --export --armor "${FP}" >"${PUB_FILE}"
	if [[ ! -s "${PUB_FILE}" ]]; then
		echo "ERROR: Public key export for ${FP} produced an empty file."
		exit 1
	fi

	# Export private key to a temporary file.
	PRIV_FILE="${tmpdir}/priv-${SHORT_ID}.asc"
	gpg --export-secret-keys --armor "${FP}" >"${PRIV_FILE}"
	if [[ ! -s "${PRIV_FILE}" ]]; then
		echo "ERROR: Private key export for ${FP} produced an empty file."
		exit 1
	fi

	# JSON-encode the armoured exports for sops.
	# Write to temp files and use --value-file to avoid leaking key material
	# in process arguments (visible via ps/proc).
	PUB_JSON_FILE="${tmpdir}/pub-${SHORT_ID}.json"
	PRIV_JSON_FILE="${tmpdir}/priv-${SHORT_ID}.json"
	jq -Rs . <"${PUB_FILE}" >"${PUB_JSON_FILE}"
	jq -Rs . <"${PRIV_FILE}" >"${PRIV_JSON_FILE}"

	# Add entries to the sops-encrypted YAML.
	echo "  Adding gpg_public_${SHORT_ID} to gnupg.yaml..."
	sops set --value-file "${SECRETS_FILE}" "[\"gpg_public_${SHORT_ID}\"]" "${PUB_JSON_FILE}"

	echo "  Adding gpg_private_${SHORT_ID} to gnupg.yaml..."
	sops set --value-file "${SECRETS_FILE}" "[\"gpg_private_${SHORT_ID}\"]" "${PRIV_JSON_FILE}"

	# Write the public key .asc file to the repository.
	ASC_FILE="${PUBKEY_DIR}/gpg-pubkey-${SHORT_ID}.asc"
	cp "${PUB_FILE}" "${ASC_FILE}"
	echo "  Wrote ${ASC_FILE}"
done

echo ""
echo "Done. 3 key pairs exported."
echo ""
echo "Secrets file: ${SECRETS_FILE}"
echo "Public keys:  ${PUBKEY_DIR}/gpg-pubkey-*.asc"
echo ""
echo "Next steps:"
echo "  1. Verify with: sops decrypt ${SECRETS_FILE} | head -20"
echo "  2. Update gpg.nix to reference the .asc files in programs.gpg.publicKeys"
echo "  3. Update sops configuration to reference gnupg.yaml"
echo "  4. Commit the public key .asc files and gnupg.yaml"
