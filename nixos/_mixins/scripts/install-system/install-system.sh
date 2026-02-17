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
	echo "  - FlakeHub: uses 'determinate-nixd login' if not already authenticated"
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

		# Prompt for disk encryption password if needed.
		if grep -q "data.passwordFile" "$DISKO_CONFIG" && [ ! -f /tmp/data.passwordFile ]; then
			while true; do
				read -rsp "Enter disk encryption password:   " password
				echo
				read -rsp "Confirm disk encryption password: " password_confirm
				echo
				if [ "$password" == "$password_confirm" ]; then
					break
				else
					echo "Passwords do not match, please try again."
				fi
			done
			echo -n "$password" >/tmp/data.passwordFile
		fi

		# Generate a LUKS keyfile if needed.
		if grep -q "keyFile" "$DISKO_CONFIG" && [ ! -f /tmp/luks.key ]; then
			dd if=/dev/urandom of=/tmp/luks.key bs=4096 count=1 iflag=fullblock
			chmod 600 /tmp/luks.key
		fi
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
if ! sudo test -e "/var/lib/private/sops/age/keys.txt"; then
	echo "ERROR! /var/lib/private/sops/age/keys.txt was not found."
	echo "       The host age key is required for the installed system to decrypt"
	echo "       sops-managed secrets at boot."
	echo ""
	echo "From a trusted workstation, run:"
	echo "  just inject-tokens $(ip route get 1.1.1.1 | awk '{print $7}' | head -n 1)"
	exit 1
fi

# --- Detect and authenticate FlakeHub ---
USE_FLAKEHUB=0
if command -v determinate-nixd >/dev/null 2>&1; then
	DNIXD_STATUS=$(determinate-nixd status 2>&1 || true)
	if echo "$DNIXD_STATUS" | grep -q "Authentication: logged-out"; then
		echo "FlakeHub Cache not authenticated."
		read -p "Run 'determinate-nixd login' now? [y/N] " -n 1 -r
		echo
		if [[ $REPLY =~ ^[Yy]$ ]]; then
			if sudo determinate-nixd login; then
				USE_FLAKEHUB=1
				echo "FlakeHub Cache authenticated. Will use cached closures where possible."
			else
				echo "WARNING! determinate-nixd login failed. Will build locally."
			fi
		else
			echo "Skipping FlakeHub login. Will build locally."
		fi
	else
		USE_FLAKEHUB=1
		echo "FlakeHub Cache available. Will use cached closures where possible."
	fi
else
	echo "determinate-nixd not found. Will build locally."
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
	# Ensure a clean target for secret and key injection.
	# On re-runs, files from a previous attempt may exist with
	# restrictive permissions that prevent overwriting.
	sudo rm -rf /mnt/etc/ssh
	sudo mkdir -p /mnt/etc/ssh

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
	if sudo test -e "/var/lib/private/sops/age/keys.txt"; then
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
	# Install-time overrides: push download parallelism higher than the
	# base config (64/128) since initial provisioning fetches thousands
	# of store paths and the ISO has no contending workload.
	if [[ "$USE_FLAKEHUB" -eq 1 ]]; then
		FLAKE_REF="wimpysworld/nix-config/*#nixosConfigurations.$TARGET_HOST"
		echo "Resolving NixOS configuration from FlakeHub Cache..."
		if SYSTEM_PATH=$(fh resolve "$FLAKE_REF"); then
			# nixos-install --system uses 'nix-env --store /mnt --set'
			# internally, so substituters (including FlakeHub Cache)
			# download the closure directly into /mnt/nix/store without
			# staging through the ISO's RAM-backed local store.
			echo "Installing NixOS from FlakeHub Cache (skipping local build)..."
			sudo nixos-install --no-root-password --no-channel-copy --system "$SYSTEM_PATH" \
				--option max-substitution-jobs 128 \
				--option http-connections 256 \
				--option narinfo-cache-negative-ttl 0
		else
			echo "WARNING! FlakeHub resolve failed; falling back to local build..."
			sudo nixos-install --no-root-password --no-channel-copy --flake ".#$TARGET_HOST" \
				--option max-substitution-jobs 128 \
				--option http-connections 256
		fi
	else
		sudo nixos-install --no-root-password --no-channel-copy --flake ".#$TARGET_HOST" \
			--option max-substitution-jobs 128 \
			--option http-connections 256
	fi

	# Remove channel artefacts created by nixos-install activation.
	# The flake sets nix.channel.enable = false but activation may
	# still create these directories, triggering spurious warnings
	# on every subsequent nixos-enter invocation.
	sudo rm -rf /mnt/root/.nix-defexpr/channels
	sudo rm -rf /mnt/nix/var/nix/profiles/per-user/root/channels

	# Rsync nix-config to the target install and set the remote origin to SSH.
	sudo rsync -a --delete "$HOME/Zero/" "/mnt/home/$TARGET_USER/Zero/"

	# Copy the sops keys.txt to the target install
	if [ -e "$HOME/.config/sops/age/keys.txt" ]; then
		sudo mkdir -p "/mnt/home/$TARGET_USER/.config/sops/age"
		sudo cp "$HOME/.config/sops/age/keys.txt" "/mnt/home/$TARGET_USER/.config/sops/age/keys.txt"
		sudo chmod 600 "/mnt/home/$TARGET_USER/.config/sops/age/keys.txt"
	fi

	# Apply the Home Manager configuration.
	sudo nixos-enter --root /mnt --command "chown -R $TARGET_USER:users /home/$TARGET_USER"
	if [[ "$USE_FLAKEHUB" -eq 1 ]]; then
		HM_REF="wimpysworld/nix-config/*#homeConfigurations.$TARGET_USER@$TARGET_HOST"
		echo "Resolving Home Manager configuration from FlakeHub Cache..."
		if HM_PATH=$(fh resolve "$HM_REF"); then
			# Use 'nix build --store /mnt' to fetch the closure directly
			# into /mnt/nix/store via configured substituters (including
			# FlakeHub Cache), mirroring the approach nixos-install uses
			# internally. This avoids staging through the ISO's limited
			# RAM-backed local store which can run out of space.
			echo "Copying Home Manager closure to target..."
			sudo nix build --store /mnt --no-link "$HM_PATH" \
				--option max-substitution-jobs 128 \
				--option http-connections 256 \
				--option narinfo-cache-negative-ttl 0
			echo "Activating Home Manager from FlakeHub Cache..."
			sudo nixos-enter --root /mnt --command "env USER=$TARGET_USER HOME=/home/$TARGET_USER $HM_PATH/activate"
		else
			echo "WARNING! FlakeHub resolve failed; falling back to local build..."
			sudo nixos-enter --root /mnt --command "cd /home/$TARGET_USER/Zero/nix-config && env USER=$TARGET_USER HOME=/home/$TARGET_USER nix run nixpkgs#home-manager -- switch -b backup --flake \".#$TARGET_USER@$TARGET_HOST\""
		fi
	else
		echo "Applying Home Manager configuration..."
		sudo nixos-enter --root /mnt --command "cd /home/$TARGET_USER/Zero/nix-config && env USER=$TARGET_USER HOME=/home/$TARGET_USER nix run nixpkgs#home-manager -- switch -b backup --flake \".#$TARGET_USER@$TARGET_HOST\""
	fi
	sudo nixos-enter --root /mnt --command "chown -R $TARGET_USER:users /home/$TARGET_USER"
fi
