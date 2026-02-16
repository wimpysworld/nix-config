#!/usr/bin/env bash

set -euo pipefail

# Locate the nix-config repository root
REPO_ROOT="${HOME}/Zero/nix-config"

function usage() {
	echo "Usage: $(basename "$0") -h HOST -r REMOTE_ADDRESS [-k] [-t]"
	echo "  -h HOST: NixOS configuration to install"
	echo "  -r REMOTE_ADDRESS: Remote address to install NixOS on"
	echo "  -k Keep disks"
	echo "  -t Test in VM"
	exit 1
}

DISKO_MODE="disko"
EXTRA=""
EXTRA_FILES=0
HOST=""
KEEP_DISKS=0
LUKS_KEY=""
LUKS_PASS=""
REMOTE_ADDRESS=""
VM_TEST=0

while getopts "kh:r:t" opt; do
	case $opt in
	h) HOST=$OPTARG ;;
	k)
		KEEP_DISKS=1
		DISKO_MODE="mount"
		;;
	r) REMOTE_ADDRESS=$OPTARG ;;
	t) VM_TEST=1 ;;
	\?) usage ;;
	esac
done

if [[ -z "${HOST}" ]] || [[ -z "${REMOTE_ADDRESS}" ]]; then
	usage
fi

if [[ -z "${USER:-}" ]] || [[ "${USER}" == "root" ]]; then
	echo "ERROR: $(basename "$0") should be run as a regular user, not root."
	exit 1
fi

# Create a temporary directory for extra files
FILES=$(mktemp -d)

# Cleanup temporary directory on exit
cleanup() {
	rm -rf "${FILES}"
}
trap cleanup EXIT

echo "Installing NixOS ${HOST} configuration on root@${REMOTE_ADDRESS}..."

if [[ "${VM_TEST}" -eq 1 ]]; then
	echo "- INFO: Testing in VM"
	EXTRA+=" --vm-test"
else
	echo "- WARN! Production install"
fi

if [[ "${KEEP_DISKS}" -eq 1 ]]; then
	echo "- INFO: Keeping disks"
	EXTRA+=" --disko-mode mount"
else
	echo "- WARN! Wiping disks"
fi

# https://github.com/nix-community/nixos-anywhere/blob/main/docs/howtos/secrets.md
# --- SOPS user age keys ---
# Sourced from the standard location on the running workstation.
USER_AGE_KEYS="${HOME}/.config/sops/age/keys.txt"
if [[ -f "${USER_AGE_KEYS}" ]]; then
	install -d -m755 "${FILES}/${HOME}/.config/sops/age"
	cp "${USER_AGE_KEYS}" "${FILES}/${HOME}/.config/sops/age/keys.txt"
	chmod 600 "${FILES}/${HOME}/.config/sops/age/keys.txt"
	chown -R 1000:100 "${FILES}/${HOME}/.config"
	echo "- INFO: Sending SOPS user keys"
	EXTRA_FILES=1
else
	echo "- WARN! No SOPS user keys found at ${USER_AGE_KEYS}"
fi

# --- SOPS host age keys ---
# Sourced from the standard location on the running workstation.
HOST_AGE_KEYS="/var/lib/private/sops/age/keys.txt"
if [[ -f "${HOST_AGE_KEYS}" ]]; then
	install -d -m755 "${FILES}/var/lib/private/sops/age"
	cp "${HOST_AGE_KEYS}" "${FILES}/var/lib/private/sops/age/keys.txt"
	chmod 600 "${FILES}/var/lib/private/sops/age/keys.txt"
	echo "- INFO: Sending SOPS host keys"
	EXTRA_FILES=1
else
	echo "- WARN! No SOPS host keys found at ${HOST_AGE_KEYS}"
fi

# --- Initrd SSH keys ---
# Extracted from sops-encrypted secrets/ssh.yaml.
SSH_SECRETS="${REPO_ROOT}/secrets/ssh.yaml"
if [[ -f "${SSH_SECRETS}" ]]; then
	install -d -m755 "${FILES}/etc/ssh"
	sops decrypt --extract '["initrd_ssh_host_ed25519_key"]' "${SSH_SECRETS}" \
		>"${FILES}/etc/ssh/initrd_ssh_host_ed25519_key"
	chmod 600 "${FILES}/etc/ssh/initrd_ssh_host_ed25519_key"
	sops decrypt --extract '["initrd_ssh_host_ed25519_key_pub"]' "${SSH_SECRETS}" \
		>"${FILES}/etc/ssh/initrd_ssh_host_ed25519_key.pub"
	chmod 644 "${FILES}/etc/ssh/initrd_ssh_host_ed25519_key.pub"
	echo "- INFO: Sending initrd SSH keys"
	EXTRA_FILES=1
else
	echo "- WARN! No initrd SSH secrets found at ${SSH_SECRETS}"
fi

# --- Host SSH keys ---
# Extracted from sops-encrypted secrets/host-<hostname>.yaml.
HOST_SECRETS="${REPO_ROOT}/secrets/host-${HOST}.yaml"
if [[ -f "${HOST_SECRETS}" ]]; then
	install -d -m755 "${FILES}/etc/ssh"
	sops decrypt --extract '["ssh_host_ed25519_key"]' "${HOST_SECRETS}" \
		>"${FILES}/etc/ssh/ssh_host_ed25519_key"
	chmod 600 "${FILES}/etc/ssh/ssh_host_ed25519_key"
	sops decrypt --extract '["ssh_host_ed25519_key_pub"]' "${HOST_SECRETS}" \
		>"${FILES}/etc/ssh/ssh_host_ed25519_key.pub"
	chmod 644 "${FILES}/etc/ssh/ssh_host_ed25519_key.pub"
	sops decrypt --extract '["ssh_host_rsa_key"]' "${HOST_SECRETS}" \
		>"${FILES}/etc/ssh/ssh_host_rsa_key"
	chmod 600 "${FILES}/etc/ssh/ssh_host_rsa_key"
	sops decrypt --extract '["ssh_host_rsa_key_pub"]' "${HOST_SECRETS}" \
		>"${FILES}/etc/ssh/ssh_host_rsa_key.pub"
	chmod 644 "${FILES}/etc/ssh/ssh_host_rsa_key.pub"
	echo "- INFO: Sending host SSH keys"
	EXTRA_FILES=1
else
	echo "- WARN! No host SSH secrets found at ${HOST_SECRETS}"
fi

# --- LUKS password and keyfile ---
if [[ "${KEEP_DISKS}" -eq 0 ]]; then
	if grep -q "data.passwordFile" "nixos/${HOST}/disks.nix"; then
		# If the machine we're provisioning expects a password to unlock a disk, prompt for it.
		while true; do
			# Prompt for the password, input is hidden
			read -rsp "Enter disk encryption password:   " password
			echo
			# Prompt for the password again for confirmation
			read -rsp "Confirm disk encryption password: " password_confirm
			echo
			# Check if both entered passwords match
			if [[ "${password}" == "${password_confirm}" ]]; then
				break
			else
				echo "Passwords do not match, please try again."
				exit 1
			fi
		done

		# Write the password to /tmp/data.passwordFile with no trailing newline
		echo -n "$password" >/tmp/data.passwordFile
		LUKS_PASS=" --disk-encryption-keys /tmp/data.passwordFile /tmp/data.passwordFile"
	fi

	if grep -q "keyFile" nixos/"${HOST}"/disk*.nix; then
		# Check if the machine we're provisioning expects a keyfile to unlock a disk.
		# If it does, generate a new key, and write to a known location.
		dd if=/dev/urandom of=/tmp/luks.key bs=4096 count=1 iflag=fullblock
		chmod 600 /tmp/luks.key
		install -d -m700 "${FILES}/etc"
		cp "/tmp/luks.key" "${FILES}/etc/luks.key"
		chmod 400 "${FILES}/etc/luks.key"
		echo "- INFO: Sending LUKS key"
		LUKS_KEY=" --disk-encryption-keys /tmp/luks.key /tmp/luks.key"
	fi
fi

if [[ "${EXTRA_FILES}" -eq 1 ]]; then
	EXTRA+=" --extra-files ${FILES}"
	tree -a "${FILES}"
fi

REPLY=""
read -p "Proceed with remote install? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
	echo "Installation aborted."
	exit 1
fi

pushd "${REPO_ROOT}" || exit 1
# shellcheck disable=2086
nix run github:nix-community/nixos-anywhere -- \
	$LUKS_PASS $LUKS_KEY --print-build-logs --flake ".#$HOST" --target-host "root@$REMOTE_ADDRESS" --disko-mode "${DISKO_MODE}" --phases kexec,disko

# shellcheck disable=2086
nix run github:nix-community/nixos-anywhere -- \
	$EXTRA --print-build-logs --chown "/home/${USER}/.config" 1000:100 --flake ".#$HOST" --target-host "root@$REMOTE_ADDRESS" --disko-mode mount --phases disko,install
popd || true
