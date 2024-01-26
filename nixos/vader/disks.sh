#!/usr/bin/env bash

# NVME (root)
#/dev/disk/by-id/nvme-Corsair_MP600_CORE_212479080001303710B4 -> /          (2TB)    nvme0n1
#/dev/disk/by-id/nvme-CT4000P3PSSD8_2336E873DCBF              -> /          (4TB)    nvme1n1
#/dev/disk/by-id/nvme-Corsair_MP600_CORE_21177909000130384189 -> /          (4TB)    nvme2n1

# SSD (borg)
#/dev/disk/by-id/ata-TS4TMTS830S_H986540074                   -> /mnt/borg  (4TB)    sda
#/dev/disk/by-id/ata-TS4TMTS830S_H986540082                   -> /mnt/borg  (4TB)    sdb
#/dev/disk/by-id/ata-Samsung_SSD_870_QVO_4TB_S5STNG0R100684E  -> /mnt/borg  (4TB)    sdc

if [ $# -eq 0 ]; then
    echo "Usage: $0 <target_user>"
    exit 1
fi
target_user="${1}"

size_esp="1024MiB"

# Array of disks to be prepared
disks_root=(/dev/nvme0n1)
disks_home=(
    /dev/nvme1n1 \
    /dev/nvme2n1 \
    /dev/sda \
    /dev/sdb \
    /dev/sdc
)
disks_all=("${disks_root[@]}" "${disks_home[@]}")

function confirm_action() {
    local MESSAGE="${1}"

    echo "ALERT! ${MESSAGE}"
    echo
    read -p "Are you sure? [y/N]" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

function unmount_if_mounted() {
    # Check if the directory path is provided
    if [ $# -eq 0 ]; then
        echo "Usage: unmount_if_mounted <directory>"
        return 1
    fi

    local directory="${1}"
    # Check if the directory is a mount point
    if mountpoint -q "${directory}"; then
        echo "Directory ${directory} is a mount point. Attempting to unmount..."
        # Attempt to unmount the directory
        if umount -q "${directory}"; then
            echo "Successfully unmounted ${directory}."
        else
            echo "Failed to unmount ${directory}. Check if it's in use."
            return 1
        fi
    else
        echo "Directory ${directory} is not a mount point."
    fi
}

# Function to stop mdadm arrays
function stop_mdadm_arrays() {
    for disk in "$@"; do
        # Check for any active mdadm arrays on the disk
        arrays=$(grep "$disk" /proc/mdstat | awk '{print $1}')

        for array in $arrays; do
            md_device="/dev/$array"
            echo "Stopping mdadm array $md_device..."

            # Unmount the array if mounted
            mountpoint=$(findmnt -n -o TARGET --source "$md_device" 2>/dev/null)
            if [ -n "$mountpoint" ]; then
                echo "Unmounting $md_device from $mountpoint..."
                umount "$md_device"
            fi

            # Stop the mdadm array
            mdadm --stop "$md_device"
        done
    done
}

function wipe_disks() {
    local disks=("$@")
    # Loop over each disk device
    for disk in "${disks[@]}"; do
        echo "Wiping ${disk}..."
        # Wipe filesystem signatures using wipefs
        wipefs --all --force "${disk}"
        # Wipe the beginning and end of the disk to remove partition table and RAID metadata
        dd if=/dev/zero of="${disk}" bs=1M count=10 status=none
        echo "$disk has been wiped."
    done
}

function output_labels() {
    local disks=("$@")
    output=""

    for disk in "${disks[@]}"; do
        # Extract the disk type and name
        if [[ ${disk} == /dev/nvme* ]]; then
            disk_type="nvme"
            disk_name="${disk##*/}"
        else
            disk_type="sata"
            disk_name="${disk##*/}"
        fi

        # Append to output string
        output+="--label=${disk_type}.${disk_name} ${disk} "
    done

    # Remove trailing space
    output=${output% }

    echo "${output}"
}

function make_uncompressed_dir() {
    local directory="${1}"
    mkdir -p "${directory}"
    bcachefs setattr --compression=none --background_compression=none "${directory}"
}

unmount_if_mounted /mnt/home
unmount_if_mounted /mnt/boot
unmount_if_mounted /mnt
stop_mdadm_arrays "${disks_all[@]}"

# Ask for confirmation before wiping disks
if confirm_action "About to WIPE the / disk(s): ${disks_root[*]}"; then
    wipe_disks "${disks_root[@]}"
fi

if confirm_action "About to FORMAT the / disk(s): ${disks_root[*]}"; then
    # Partition the first root disk
    parted "${disks_root[0]}" -- mklabel gpt
    parted "${disks_root[0]}" -- mkpart ESP fat32 1MiB "${size_esp}"
    parted "${disks_root[0]}" -- set 1 esp on
    parted "${disks_root[0]}" -- set 1 boot on
    parted "${disks_root[0]}" -- mkpart primary "${size_esp}" 100%

    # Create the /boot filesystem
    mkfs.fat -F 32 -n ESP "${disks_root[0]}p1"

    # Create the / filesystem
    bcachefs format -f --fs_label=root --uuid=cafeface-b007-b007-b007-0c278079e5e6 \
        --background_compression=lz4:0 \
        --compression=lz4:1 \
        --discard \
        "${disks_root[0]}p2"
fi

# mount the filesystems
echo "Mount: /"
bcachefs mount -o relatime,nodiratime,background_compression=lz4:0,compression=lz4:1,discard /dev/disk/by-label/root /mnt

echo "Mount: /boot"
mkdir -p /mnt/boot 2>/dev/null
mount -o umask=0077 /dev/disk/by-label/ESP /mnt/boot

if [ ${#disks_home[@]} -ne 0 ]; then
    if confirm_action "About to WIPE the /home disk(s): ${disks_home[*]}"; then
        wipe_disks "${disks_home[@]}"
    fi

    if confirm_action "About to FORMAT the /home disk(s): ${disks_home[*]}"; then
        bcachefs format -f --fs_label=home --uuid=deadbeef-da7a-da7a-da7a-ab86f7c169a6 \
            --background_compression=lz4:0 \
            --compression=lz4:1 \
            --discard \
            --encrypted \
            $(output_labels "${disks_home[@]}") \
            --foreground_target=nvme \
            --promote_target=nvme \
            --background_target=sata \
            --replicas=2
    fi

    # Unlock the encrypted /home filesystem
    # - https://nixos.wiki/wiki/Bcachefs#NixOS_installation_on_bcachefs
    # - https://github.com/NixOS/nixpkgs/issues/32279
    if bcachefs unlock -c /dev/disk/by-label/home; then
        keyctl link @u @s
        bcachefs unlock /dev/disk/by-label/home
    fi

    echo "Mount: /home"
    mkdir -p /mnt/home 2>/dev/null
    bcachefs mount -o relatime,nodiratime,background_compression=lz4:0,compression=lz4:1,discard "$(echo "${disks_home[*]}" | sed 's/ /:/g')" /mnt/home
    # Create the user's home directory as a subvolume
    bcachefs subvolume create "/mnt/home/${target_user}"
    # Create directories that will store data I do not want to be compressed
    make_uncompressed_dir "/mnt/home/${target_user}/Audio"
    make_uncompressed_dir "/mnt/home/${target_user}/Music"
    make_uncompressed_dir "/mnt/home/${target_user}/Pictures"
    make_uncompressed_dir "/mnt/home/${target_user}/Quickemu"
    make_uncompressed_dir "/mnt/home/${target_user}/Videos"
    chown -R 1000:100 "/mnt/home/${target_user}"
    # Create the snapshots directory
    mkdir -p --mode=700 /mnt/home/snapshots
    chown -R 1000:100 /mnt/home/snapshots
fi
