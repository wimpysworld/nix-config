#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset
set +o pipefail  # Disable pipefail

TARGET_HOST="${1:-}"
TARGET_USER="${2:-martin}"
TARGET_BRANCH="${3:-main}"

function run_disko() {
    local DISKO_CONFIG="$1"
    local REPLY="n"

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
        # Workaround for mounting encrypted bcachefs filesystems.
        # - https://nixos.wiki/wiki/Bcachefs#NixOS_installation_on_bcachefs
        # - https://github.com/NixOS/nixpkgs/issues/32279
        sudo keyctl link @u @s
        sudo disko --mode disko "$DISKO_CONFIG"
    else
        sudo disko --mode mount "$DISKO_CONFIG"
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

pushd "$HOME/Zero/nix-config"

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

if [ ! -e "$HOME/.config/sops/age/keys.txt" ]; then
    echo "WARNING! $HOME/.config/sops/age/keys.txt was not found."
    echo "         Do you want to continue without it?"
    echo
    read -p "Are you sure? [y/N]" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        IP=$(ip route get 1.1.1.1 | awk '{print $7}' | head -n 1)
        mkdir -p "$HOME/.config/sops/age" 2>/dev/null || true
        echo "From a trusted host run:"
        echo "scp ~/.config/sops/age/keys.txt $USER@$IP:.config/sops/age/keys.txt"
        exit
    fi
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
        read -rsp "Enter password:   " password
        echo
        # Prompt for the password again for confirmation
        read -rsp "Confirm password: " password_confirm
        echo
        # Check if both entered passwords match
        if [ "$password" == "$password_confirm" ]; then
            break
        else
            echo "Passwords do not match, please try again."
        fi
    done

    # Write the password to /tmp/data.passwordFile with no trailing newline
    echo -n "$password" > /tmp/data.passwordFile
fi

if grep -q "data.keyFile" "nixos/$TARGET_HOST/disks.nix"; then
    # Check if the machine we're provisioning expects a keyfile to unlock a disk.
    # If it does, generate a new key, and write to a known location.
    echo -n "$(head -c32 /dev/random | base64)" > /tmp/data.keyFile
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
    # Copy the sops keys.txt to the target install
    sudo nixos-install --no-root-password --flake ".#$TARGET_HOST"

    # Rsync nix-config to the target install and set the remote origin to SSH.
    rsync -a --delete "$HOME/Zero/" "/mnt/home/$TARGET_USER/Zero/"
    if [ "$TARGET_HOST" != "crawler" ] && [ "$TARGET_HOST" != "dagger" ]; then
        pushd "/mnt/home/$TARGET_USER/Zero/nix-config"
        git remote set-url origin git@github.com:wimpysworld/nix-config.git
        popd
    fi

    # Copy the sops keys.txt to the target install
    if [ -e "$HOME/.config/sops/age/keys.txt" ]; then
        mkdir -p "/mnt/home/$TARGET_USER/.config/sops/age"
        cp "$HOME/.config/sops/age/keys.txt" "/mnt/home/$TARGET_USER/.config/sops/age/keys.txt"
        chmod 600 "/mnt/home/$TARGET_USER/.config/sops/age/keys.txt"
    fi

    # Enter to the new install and apply the home-manager configuration.
    sudo nixos-enter --root /mnt --command "chown -R $TARGET_USER:users /home/$TARGET_USER"
    sudo nixos-enter --root /mnt --command "cd /home/$TARGET_USER/Zero/nix-config; env USER=$TARGET_USER HOME=/home/$TARGET_USER home-manager switch --flake \".#$TARGET_USER@$TARGET_HOST\""
    sudo nixos-enter --root /mnt --command "chown -R $TARGET_USER:users /home/$TARGET_USER"

    # If there is a keyfile for a data disk, put copy it to the root partition and
    # ensure the permissions are set appropriately.
    if [[ -f "/tmp/data.keyFile" ]]; then
        sudo cp /tmp/data.keyFile /mnt/etc/data.keyFile
        sudo chmod 0400 /mnt/etc/data.keyFile
    fi
fi
