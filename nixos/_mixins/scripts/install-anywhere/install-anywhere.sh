#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset
set +o pipefail  # Disable pipefail

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
    h ) HOST=$OPTARG;;
    k )
      KEEP_DISKS=1
      DISKO_MODE="mount"
      ;;
    r ) REMOTE_ADDRESS=$OPTARG;;
    t ) VM_TEST=1;;
    \? ) usage;;
  esac
done

if [ -z "$HOST" ] || [ -z "$REMOTE_ADDRESS" ]; then
  usage
fi

# Create a temporary directory
FILES=$(mktemp -d)

# Function to cleanup temporary directory on exit
function cleanup() {
  rm -rf "$FILES"
}
trap cleanup EXIT

echo "Installing NixOS $HOST configuration on root@$REMOTE_ADDRESS..."

if [ "$VM_TEST" -eq 1 ]; then
  echo "- INFO: Testing in VM"
  EXTRA+=" --vm-test"
else
  echo "- WARN! Production install"
fi

if [ "$KEEP_DISKS" -eq 1 ]; then
  echo "- INFO: Keeping disks"
  EXTRA+=" --disko-mode mount"
else
  echo "- WARN! Wiping disks"
fi

if [ -d "$HOME/Vaults/Secrets/ssh" ]; then
  # https://github.com/nix-community/nixos-anywhere/blob/main/docs/howtos/secrets.md
  if [ -e "$HOME/Vaults/Secrets/age/user/keys-$USER.txt" ]; then
    install -d -m755 "$FILES/$HOME/.config/sops/age"
    cp "$HOME/Vaults/Secrets/age/user/keys-$USER.txt" \
      "$FILES/$HOME/.config/sops/age/keys.txt"
    chmod 600 "$FILES/$HOME/.config/sops/age/keys.txt"
    chown -R 1000:100 "$FILES/$HOME/.config"
    echo "- INFO: Sending SOPS user keys"
    EXTRA_FILES=1
  else
    echo "- WARN! No SOPS user keys found"
  fi

  if [ -e "$HOME/Vaults/Secrets/age/host/keys-prime.txt" ]; then
    install -d -m755 "$FILES/var/lib/private/sops/age"
    cp "$HOME/Vaults/Secrets/age/host/keys-prime.txt" \
      "$FILES/var/lib/private/sops/age/keys.txt"
    chmod 600 "$FILES/var/lib/private/sops/age/keys.txt"
    echo "- INFO: Sending SOPS host keys"
    EXTRA_FILES=1
  else
    echo "- WARN! No SOPS host keys found"
  fi

  if [ -e "$HOME/Vaults/Secrets/ssh/initrd_ssh_host_ed25519_key" ]; then
    install -d -m755 "$FILES/etc/ssh"
    cp "$HOME/Vaults/Secrets/ssh/initrd_ssh_host_ed25519_key" "$FILES/etc/ssh/"
    cp "$HOME/Vaults/Secrets/ssh/initrd_ssh_host_ed25519_key.pub" "$FILES/etc/ssh/"
    chmod 600 "$FILES/etc/ssh/initrd_ssh_host_ed25519_key"
    chmod 644 "$FILES/etc/ssh/initrd_ssh_host_ed25519_key.pub"
    echo "- INFO: Sending initrd SSH keys"
    EXTRA_FILES=1
  else
    echo "- WARN! No initrd SSH keys found"
  fi

  if [ -e "$HOME/Vaults/Secrets/ssh/$HOST/ssh_host_ed25519_key" ]; then
    install -d -m755 "$FILES/etc/ssh"
    cp "$HOME/Vaults/Secrets/ssh/$HOST/ssh_host_ed25519_key" "$FILES/etc/ssh/"
    cp "$HOME/Vaults/Secrets/ssh/$HOST/ssh_host_ed25519_key.pub" "$FILES/etc/ssh/"
    cp "$HOME/Vaults/Secrets/ssh/$HOST/ssh_host_rsa_key" "$FILES/etc/ssh/"
    cp "$HOME/Vaults/Secrets/ssh/$HOST/ssh_host_rsa_key.pub" "$FILES/etc/ssh/"
    chmod 600 "$FILES/etc/ssh/ssh_host_ed25519_key"
    chmod 644 "$FILES/etc/ssh/ssh_host_ed25519_key.pub"
    chmod 600 "$FILES/etc/ssh/ssh_host_rsa_key"
    chmod 644 "$FILES/etc/ssh/ssh_host_rsa_key.pub"
    echo "- INFO: Sending host SSH keys"
    EXTRA_FILES=1
  else
    echo "- WARN! No host SSH keys found"
  fi

  if [ $KEEP_DISKS -eq 0 ]; then
    if grep -q "data.passwordFile" "nixos/$HOST/disks.nix"; then
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
              exit 1
          fi
      done

      # Write the password to /tmp/data.passwordFile with no trailing newline
      echo -n "$password" > /tmp/data.passwordFile
      LUKS_PASS=" --disk-encryption-keys /tmp/data.passwordFile /tmp/data.passwordFile"
    fi

    if [ -e "$HOME/Vaults/Secrets/luks/$HOST.key" ]; then
        install -d -m700 "$FILES/vault"
        cp "$HOME/Vaults/Secrets/luks/$HOST.key" "$FILES/vault/luks.key"
        chmod 400 "$FILES/vault/luks.key"
        echo "- INFO: Sending LUKS key"

        cp -v "$HOME/Vaults/Secrets/luks/$HOST.key" /tmp/luks.key
        LUKS_KEY=" --disk-encryption-keys /tmp/luks.key /tmp/luks.key"
        # Switch the LUKS keyFile to /tmp for the install phase
        for DISK in nixos/"$HOST"/disk*.nix; do
          if grep -q "keyFile" "$DISK"; then
            echo "- INFO: Found keyFile in $DISK, updating to /tmp/luks.key"
            sed -i 's|/vault/luks|/tmp/luks|' "$DISK"
          fi
        done
      else
        echo "- WARN! No LUKS key found"
      fi
    fi
else
  echo "ERROR: The Secrets Vaults is not mounted."
  exit 1
fi

if [ "$EXTRA_FILES" -eq 1 ]; then
  EXTRA+=" --extra-files $FILES"
  tree -a "$FILES"
fi

REPLY="n"
read -p "Proceed with remote install? [y/N]" -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
  echo "Installation aborted."
  exit 1
fi

pushd "$HOME/Zero/nix-config" || exit 1
# shellcheck disable=2086
nix run github:nix-community/nixos-anywhere -- \
  $LUKS_PASS $LUKS_KEY --print-build-logs --flake ".#$HOST" --disko-mode "${DISKO_MODE}" --phases kexec,disko "root@$REMOTE_ADDRESS"

rm -f /tmp/luks.key
# Switch the LUKS keyFile to the vault location if it was set
if [ -n "$LUKS_PASS" ]; then
  for DISK in nixos/"$HOST"/disk*.nix; do
    if grep -q "keyFile" "$DISK"; then
      echo "- INFO: Found keyFile in $DISK, updating to /vault/luks.key"
      sed -i 's|/tmp/luks|/vault/luks|' "$DISK"
    fi
  done
fi

# shellcheck disable=2086
nix run github:nix-community/nixos-anywhere -- \
  $EXTRA --print-build-logs --chown /home/$USER/.config 1000:100 --flake ".#$HOST" --disko-mode mount --phases disko,install "root@$REMOTE_ADDRESS"
popd || true
