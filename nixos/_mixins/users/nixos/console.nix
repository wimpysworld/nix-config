{ pkgs, ... }:
let
  install-system = pkgs.writeScriptBin "install-system" ''
#!${pkgs.stdenv.shell}

set -euo pipefail

TARGET_HOST="$1"
TARGET_USER="$2"

if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR! $(basename "$0") should be run as a regular user"
  exit 1
fi

if [ ! -d "$HOME/Zero/nix-config/.git" ]; then
  git clone https://github.com/wimpysworld/nix-config.git "$HOME/Zero/nix-config"
fi

cd "$HOME/Zero/nix-config"
git remote set-url origin git@github.com:wimpysworld/nix-config.git

if [[ -z "$TARGET_HOST" ]]; then
  echo "ERROR! $(basename "$0") requires a hostname as the first argument"
  ls -1 nixos/*/boot.nix | cut -d'/' -f2 | grep -v live
  exit 1
fi

if [[ -z "$TARGET_USER" ]]; then
  echo "ERROR! $(basename "$0") requires a username as the second argument"
  ls -1 nixos/_mixins/users/ | grep -v -E "nixos|root"
  exit 1
fi

if [ ! -e "nixos/$TARGET_HOST/disks.nix" ]; then
  echo "ERROR! $(basename "$0") could not find the required nixos/$TARGET_HOST/disks.nix"
  exit 1
fi

# Check if the machine we're provisioning expects a keyfile to unlock a disk.
# If it does, generate a new key, and write to a known location.
if grep -q "data.keyfile" "host/$TARGET_HOST/disks.nix"; then
  echo -n "$(head -c32 /dev/random | base64)" > /tmp/data.keyfile
fi

echo "WARNING! The disks in $TARGET_HOST are about to get wiped"
echo "         NixOS will be re-installed"
echo "         This is a destructive operation"
echo
read -p "Are you sure? [y/N]" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  sudo true

  sudo nix run github:nix-community/disko \
    --extra-experimental-features "nix-command flakes" \
    --no-write-lock-file \
    -- \
    --mode zap_create_mount \
    "nixos/$TARGET_HOST/disks.nix"

  sudo nixos-install --no-root-password --flake ".#$TARGET_HOST"

  # Create dirs for home-manager
  # FIXME: This should be done via nixos/_mixins/base/default.nix
  #        But it only works in the live iso, not an installed system.
  sudo mkdir -p "/mnt/nix/var/nix/profiles/per-user/$TARGET_USER"

  # Rsync nix-config to the target install
  rsync -a --delete "$HOME/Zero/" "/mnt/home/$TARGET_USER/Zero/"

  # If there is a keyfile for a data disk, put copy it to the root partition and
  # ensure the permissions are set appropriately.
  if [[ -f "/tmp/data.keyfile" ]]; then
    sudo cp /tmp/data.keyfile /mnt/etc/data.keyfile
    sudo chmod 0400 /mnt/etc/data.keyfile
  fi
fi
'';
in {
  environment.systemPackages = [ install-system ];
}
