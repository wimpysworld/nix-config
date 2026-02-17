#!/usr/bin/env bash

set -euo pipefail

function usage() {
	echo "Usage: $(basename "$0") <hostname> [username] [branch]"
	echo
	echo "  hostname   NixOS configuration to install (required)"
	echo "  username   Target user (default: martin)"
	echo "  branch     Git branch to use (default: main)"
	echo
	echo "The install path is determined automatically:"
	echo "  - Age keys: required (inject with 'just inject-tokens' or SCP manually)"
	echo "  - FlakeHub netrc: if present, uses FlakeHub Cache; otherwise builds locally"
}

TARGET_HOST="${1:-}"
TARGET_USER="${2:-martin}"
TARGET_BRANCH="${3:-main}"

function run_disko() {
	local DISKO_CONFIG="$1"
	local REPLY="n"
	local DISKO_MODE="mount"

	# If the requested config doesn't exist, skip it.
	if [ ! -e "$DISKO_CONFIG" ]; then
		return
	fi

	echo "ALERT! Found $DISKO_CONFIG"
	echo "       Do you want to format the disks in $DISKO_CONFIG"
	echo "       This is a destructive operation!"
	echo
	read -p "Proceed with $DISKO_CONFIG format? [y/N]" -n 1 -r
	echo

	sudo true
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		DISKO_MODE="destroy,format,mount"
	fi
	if command -v disko >/dev/null 2>&1; then
		sudo disko --mode "$DISKO_MODE" "$DISKO_CONFIG"
	else
		sudo nix run github:nix-community/disko/latest -- --mode "$DISKO_MODE" "$DISKO_CONFIG"
	fi
}

sudo umount -R /mnt || true

if [ "$(id -u)" -eq 0 ]; then
	echo "ERROR! $(basename "$0") should be run as a regular user"
	exit 1
fi

if [ ! -d "$HOME/Zero/nix-config/.git" ]; then
	git clone https://github.com/wimpysworld/nix-config.git "$HOME/Zero/nix-config"
fi

pushd "$HOME/Zero/nix-config" || exit 1

if [[ -n "$TARGET_BRANCH" ]]; then
	git checkout "$TARGET_BRANCH"
fi

if [[ -z "$TARGET_HOST" ]]; then
	echo "ERROR! $(basename "$0") requires a hostname as the first argument"
	echo "       The following hosts are available"
	find nixos -mindepth 2 -maxdepth 2 -type f -name default.nix | cut -d'/' -f2 | grep -v iso
	exit 1
fi

if [[ -z "$TARGET_USER" ]]; then
	echo "ERROR! $(basename "$0") requires a username as the second argument"
	echo "       The following users are available"
	find nixos/_mixins/users/ -mindepth 1 -maxdepth 1 -type d | cut -d'/' -f4 | grep -v -E "nixos|root"
	exit 1
fi

# --- Ingest injected tokens ---
# If just inject-tokens was run from the workstation, files will be
# in /tmp/injected-tokens/. Copy them to their final locations before
# proceeding with the existing guardrail checks.
INJECTED_DIR="/tmp/injected-tokens"
if [[ -d "${INJECTED_DIR}" ]]; then
	echo "Found injected tokens. Processing..."

	if [[ -f "${INJECTED_DIR}/user-age-keys.txt" ]]; then
		mkdir -p "${HOME}/.config/sops/age"
		cp "${INJECTED_DIR}/user-age-keys.txt" "${HOME}/.config/sops/age/keys.txt"
		chmod 600 "${HOME}/.config/sops/age/keys.txt"
		echo "- Installed user SOPS age key"
	fi

	if [[ -f "${INJECTED_DIR}/host-age-keys.txt" ]]; then
		sudo mkdir -p "/var/lib/private/sops/age"
		sudo cp "${INJECTED_DIR}/host-age-keys.txt" "/var/lib/private/sops/age/keys.txt"
		sudo chmod 600 "/var/lib/private/sops/age/keys.txt"
		echo "- Installed host SOPS age key"
	fi

	if [[ -f "${INJECTED_DIR}/netrc" ]]; then
		sudo mkdir -p "/nix/var/determinate"
		sudo cp "${INJECTED_DIR}/netrc" "/nix/var/determinate/netrc"
		sudo chmod 600 "/nix/var/determinate/netrc"
		echo "- Installed FlakeHub netrc"
	fi

	# Clean up the injection directory after processing
	rm -rf "${INJECTED_DIR}"
	echo "Token ingestion complete."
	echo ""
fi

# --- Hard stop: user age key required ---
if [ ! -e "$HOME/.config/sops/age/keys.txt" ]; then
	echo "ERROR! $HOME/.config/sops/age/keys.txt was not found."
	echo "       The user age key is required to decrypt sops-managed secrets."
	echo ""
	echo "From a trusted workstation, run:"
	echo "  just inject-tokens $(ip route get 1.1.1.1 | awk '{print $7}' | head -n 1)"
	exit 1
fi

# --- Hard stop: host age key required ---
if [ ! -e "/var/lib/private/sops/age/keys.txt" ]; then
	echo "ERROR! /var/lib/private/sops/age/keys.txt was not found."
	echo "       The host age key is required for the installed system to decrypt"
	echo "       sops-managed secrets at boot."
	echo ""
	echo "From a trusted workstation, run:"
	echo "  just inject-tokens $(ip route get 1.1.1.1 | awk '{print $7}' | head -n 1)"
	exit 1
fi

# --- Detect FlakeHub availability ---
USE_FLAKEHUB=0
NETRC_PATH="/nix/var/determinate/netrc"
if [ -f "$NETRC_PATH" ] && fh status 2>/dev/null | grep -q "Logged in: true"; then
	USE_FLAKEHUB=1
	echo "FlakeHub Cache available. Will use cached closures where possible."
else
	echo "FlakeHub Cache not available. Will build locally."
fi

if [ -x "nixos/$TARGET_HOST/disks.sh" ]; then
	if ! sudo "nixos/$TARGET_HOST/disks.sh" "$TARGET_USER"; then
		echo "ERROR! Failed to prepare disks; stopping here!"
		exit 1
	fi
else
	if [ ! -e "nixos/$TARGET_HOST/disks.nix" ]; then
		echo "ERROR! $(basename "$0") could not find the required nixos/$TARGET_HOST/disks.nix"
		exit 1
	fi

	if grep -q "data.passwordFile" "nixos/$TARGET_HOST/disks.nix"; then
		# If the machine we're provisioning expects a password to unlock a disk, prompt for it.
		while true; do
			# Prompt for the password, input is hidden
			read -rsp "Enter disk encryption password:   " password
			echo
			# Prompt for the password again for confirmation
			read -rsp "Confirm disk encryption password: " password_confirm
			echo
			# Check if both entered passwords match
			if [ "$password" == "$password_confirm" ]; then
				break
			else
				echo "Passwords do not match, please try again."
			fi
		done

		# Write the password to /tmp/data.passwordFile with no trailing newline
		echo -n "$password" >/tmp/data.passwordFile
	fi

	if grep -q "keyFile" nixos/"$TARGET_HOST"/disk*.nix; then
		# Check if the machine we're provisioning expects a keyfile to unlock a disk.
		# If it does, generate a new key, and write to a known location.
		dd if=/dev/urandom of=/tmp/luks.key bs=4096 count=1 iflag=fullblock
		chmod 600 /tmp/luks.key
	fi

	run_disko "nixos/$TARGET_HOST/disks.nix"

	for CONFIG in $(find "nixos/$TARGET_HOST" -name "disks-*.nix" | sort); do
		run_disko "$CONFIG"
	done
fi

if ! mountpoint -q /mnt; then
	echo "ERROR! /mnt is not mounted; make sure the disk preparation was successful."
	exit 1
fi

echo "WARNING! NixOS will be re-installed"
echo "         This is a destructive operation!"
echo
read -p "Are you sure? [y/N]" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
	# If there is a keyfile for another disk, copy it to the root
	# partition and ensure the permissions are set appropriately.
	if [[ -f "/tmp/luks.key" ]]; then
		sudo mkdir -p /mnt/etc
		sudo cp /tmp/luks.key /mnt/etc/luks.key
		sudo chmod 400 /mnt/etc/luks.key
	fi

	# Copy the host SOPS age keys to the target install.
	# Without this, the installed system cannot decrypt any sops-managed
	# secrets at boot. The user was warned and offered to abort earlier
	# if this key was missing.
	if [ -e "/var/lib/private/sops/age/keys.txt" ]; then
		echo "Copying host SOPS age keys..."
		sudo mkdir -p "/mnt/var/lib/private/sops/age"
		sudo cp "/var/lib/private/sops/age/keys.txt" "/mnt/var/lib/private/sops/age/keys.txt"
		sudo chmod 600 "/mnt/var/lib/private/sops/age/keys.txt"
	else
		echo "WARNING! Skipping host SOPS age key copy; key not found."
	fi

	# Decrypt and inject SSH host keys from sops-encrypted secrets.
	# This requires the user age key to be present, as sops uses it to
	# decrypt the secrets files.
	if [ -e "$HOME/.config/sops/age/keys.txt" ]; then
		# --- Initrd SSH keys ---
		# Extracted from sops-encrypted secrets/ssh.yaml.
		SSH_SECRETS="secrets/ssh.yaml"
		if [ -f "$SSH_SECRETS" ]; then
			echo "Decrypting initrd SSH keys..."
			sudo mkdir -p "/mnt/etc/ssh"
			sops decrypt --extract '["initrd_ssh_host_ed25519_key"]' "$SSH_SECRETS" |
				sudo tee "/mnt/etc/ssh/initrd_ssh_host_ed25519_key" >/dev/null
			sudo chmod 600 "/mnt/etc/ssh/initrd_ssh_host_ed25519_key"
			sops decrypt --extract '["initrd_ssh_host_ed25519_key_pub"]' "$SSH_SECRETS" |
				sudo tee "/mnt/etc/ssh/initrd_ssh_host_ed25519_key.pub" >/dev/null
			sudo chmod 644 "/mnt/etc/ssh/initrd_ssh_host_ed25519_key.pub"
		else
			echo "WARNING! $SSH_SECRETS was not found."
			echo "         Initrd SSH host keys will not be injected."
		fi

		# --- Per-host SSH keys ---
		# Extracted from sops-encrypted secrets/host-<hostname>.yaml.
		HOST_SECRETS="secrets/host-${TARGET_HOST}.yaml"
		if [ -f "$HOST_SECRETS" ]; then
			echo "Decrypting host SSH keys for ${TARGET_HOST}..."
			sudo mkdir -p "/mnt/etc/ssh"
			sops decrypt --extract '["ssh_host_ed25519_key"]' "$HOST_SECRETS" |
				sudo tee "/mnt/etc/ssh/ssh_host_ed25519_key" >/dev/null
			sudo chmod 600 "/mnt/etc/ssh/ssh_host_ed25519_key"
			sops decrypt --extract '["ssh_host_ed25519_key_pub"]' "$HOST_SECRETS" |
				sudo tee "/mnt/etc/ssh/ssh_host_ed25519_key.pub" >/dev/null
			sudo chmod 644 "/mnt/etc/ssh/ssh_host_ed25519_key.pub"
			sops decrypt --extract '["ssh_host_rsa_key"]' "$HOST_SECRETS" |
				sudo tee "/mnt/etc/ssh/ssh_host_rsa_key" >/dev/null
			sudo chmod 600 "/mnt/etc/ssh/ssh_host_rsa_key"
			sops decrypt --extract '["ssh_host_rsa_key_pub"]' "$HOST_SECRETS" |
				sudo tee "/mnt/etc/ssh/ssh_host_rsa_key.pub" >/dev/null
			sudo chmod 644 "/mnt/etc/ssh/ssh_host_rsa_key.pub"
		else
			echo "WARNING! $HOST_SECRETS was not found."
			echo "         Host SSH keys for ${TARGET_HOST} will not be injected."
		fi
	else
		echo "WARNING! User age key not found; skipping SSH key decryption."
		echo "         SSH host keys will not be injected (sops requires the user age key)."
	fi

	# Install NixOS to the target.
	if [[ "$USE_FLAKEHUB" -eq 1 ]]; then
		FLAKE_REF="wimpysworld/nix-config/*#nixosConfigurations.$TARGET_HOST"
		echo "Resolving NixOS configuration from FlakeHub Cache..."
		if SYSTEM_PATH=$(fh resolve "$FLAKE_REF"); then
			echo "Installing NixOS from FlakeHub Cache (skipping local build)..."
			sudo nixos-install --no-root-password --system "$SYSTEM_PATH"
		else
			echo "WARNING! FlakeHub resolve failed; falling back to local build..."
			sudo nixos-install --no-root-password --flake ".#$TARGET_HOST"
		fi
	else
		sudo nixos-install --no-root-password --flake ".#$TARGET_HOST"
	fi

	# Rsync nix-config to the target install and set the remote origin to SSH.
	sudo rsync -a --delete "$HOME/Zero/" "/mnt/home/$TARGET_USER/Zero/"

	# Copy the sops keys.txt to the target install
	if [ -e "$HOME/.config/sops/age/keys.txt" ]; then
		sudo mkdir -p "/mnt/home/$TARGET_USER/.config/sops/age"
		sudo cp "$HOME/.config/sops/age/keys.txt" "/mnt/home/$TARGET_USER/.config/sops/age/keys.txt"
		sudo chmod 600 "/mnt/home/$TARGET_USER/.config/sops/age/keys.txt"
	fi

	# Enter to the new install and apply the Home Manager configuration.
	sudo nixos-enter --root /mnt --command "chown -R $TARGET_USER:users /home/$TARGET_USER"
	if [[ "$USE_FLAKEHUB" -eq 1 ]]; then
		# Copy the FlakeHub netrc to the target so fh can authenticate
		# inside the chroot.
		if [ -f "$NETRC_PATH" ]; then
			sudo mkdir -p "/mnt/nix/var/determinate"
			sudo cp "$NETRC_PATH" "/mnt/nix/var/determinate/netrc"
			sudo chmod 600 "/mnt/nix/var/determinate/netrc"
		fi

		HM_REF="wimpysworld/nix-config/*#homeConfigurations.$TARGET_USER@$TARGET_HOST"
		echo "Applying Home Manager configuration from FlakeHub Cache..."
		if sudo nixos-enter --root /mnt --command "su - $TARGET_USER -c 'fh apply home-manager \"$HM_REF\"'"; then
			echo "Home Manager applied from FlakeHub Cache."
		else
			echo "WARNING! FlakeHub Home Manager apply failed; falling back to local build..."
			sudo nixos-enter --root /mnt --command "cd /home/$TARGET_USER/Zero/nix-config; env USER=$TARGET_USER HOME=/home/$TARGET_USER home-manager switch --flake \".#$TARGET_USER@$TARGET_HOST\""
		fi
	else
		sudo nixos-enter --root /mnt --command "cd /home/$TARGET_USER/Zero/nix-config; env USER=$TARGET_USER HOME=/home/$TARGET_USER home-manager switch --flake \".#$TARGET_USER@$TARGET_HOST\""
	fi
	sudo nixos-enter --root /mnt --command "chown -R $TARGET_USER:users /home/$TARGET_USER"
fi
