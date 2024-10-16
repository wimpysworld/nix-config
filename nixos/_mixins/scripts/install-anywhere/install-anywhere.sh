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

EXTRA=""
EXTRA_FILES=0
HOST=""
KEEP_DISKS=0
REMOTE_ADDRESS=""
VM_TEST=1

while getopts "k:h:r:t" opt; do
  case $opt in
    h ) HOST=$OPTARG;;
    k ) KEEP_DISKS=1;;
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

# https://github.com/nix-community/nixos-anywhere/blob/main/docs/howtos/secrets.md
if [ -e "$HOME/Keybase/private/wimpress/Secrets/age/user/keys-$USER.txt" ]; then
  install -d -m755 "$FILES/$HOME/.config/sops/age"
  cp "$HOME/Keybase/private/wimpress/Secrets/age/user/keys-$USER.txt" \
    "$FILES/$HOME/.config/sops/age/keys.txt"
  chmod 600 "$FILES/$HOME/.config/sops/age/keys.txt"
  chown 1000:100 "$FILES/$HOME/.config/sops/age/keys.txt"
  echo "- INFO: Sending SOPS user keys"
  EXTRA_FILES=1
else
  echo "- WARN! No SOPS user keys found"
fi

if [ -e "$HOME/Keybase/private/wimpress/Secrets/age/host/keys-prime.txt" ]; then
  install -d -m755 "$FILES/var/lib/private/sops/age"
  cp "$HOME/Keybase/private/wimpress/Secrets/age/host/keys-prime.txt" \
    "$FILES/var/lib/private/sops/age/keys.txt"
  chmod 600 "$FILES/var/lib/private/sops/age/keys.txt"
  echo "- INFO: Sending SOPS host keys"
  EXTRA_FILES=1
else
  echo "- WARN! No SOPS host keys found"
fi

if [ -e "$HOME/Keybase/private/wimpress/Secrets/ssh/initrd_ssh_host_ed25519_key" ]; then
  install -d -m755 "$FILES/etc/ssh"
  cp "$HOME/Keybase/private/wimpress/Secrets/ssh/initrd_ssh_host_ed25519_key" "$FILES/etc/ssh/"
  cp "$HOME/Keybase/private/wimpress/Secrets/ssh/initrd_ssh_host_ed25519_key.pub" "$FILES/etc/ssh/"
  chmod 600 "$FILES/etc/ssh/initrd_ssh_host_ed25519_key"
  chmod 644 "$FILES/etc/ssh/initrd_ssh_host_ed25519_key.pub"
  echo "- INFO: Sending initrd SSH keys"
  EXTRA_FILES=1
else
  echo "- WARN! No initrd SSH keys found"
fi

if [ -e "$HOME/Keybase/private/wimpress/Secrets/ssh/$HOST/ssh_host_ed25519_key" ]; then
  install -d -m755 "$FILES/etc/ssh"
  cp "$HOME/Keybase/private/wimpress/Secrets/ssh/$HOST/ssh_host_ed25519_key" "$FILES/etc/ssh/"
  cp "$HOME/Keybase/private/wimpress/Secrets/ssh/$HOST/ssh_host_ed25519_key.pub" "$FILES/etc/ssh/"
  cp "$HOME/Keybase/private/wimpress/Secrets/ssh/$HOST/ssh_host_rsa_key" "$FILES/etc/ssh/"
  cp "$HOME/Keybase/private/wimpress/Secrets/ssh/$HOST/ssh_host_rsa_key.pub" "$FILES/etc/ssh/"
  chmod 600 "$FILES/etc/ssh/ssh_host_ed25519_key"
  chmod 644 "$FILES/etc/ssh/ssh_host_ed25519_key.pub"
  chmod 600 "$FILES/etc/ssh/ssh_host_rsa_key"
  chmod 644 "$FILES/etc/ssh/ssh_host_rsa_key.pub"
  echo "- INFO: Sending host SSH keys"
  EXTRA_FILES=1
else
  echo "- WARN! No host SSH keys found"
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
  $EXTRA --flake ".#$HOST" "root@$REMOTE_ADDRESS"
popd || true
