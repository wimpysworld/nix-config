#!/usr/bin/env bash

# Array of disk devices to be wiped
disks=(/dev/vda) # Replace with actual device names

unmount_if_mounted() {
    # Check if the directory path is provided
    if [ $# -eq 0 ]; then
        echo "Usage: unmount_if_mounted <directory>"
        return 1
    fi

    local directory=$1

    # Check if the directory is a mount point
    if mountpoint -q "$directory"; then
        echo "Directory $directory is a mount point. Attempting to unmount..."
        # Attempt to unmount the directory
        if umount "$directory"; then
            echo "Successfully unmounted $directory."
        else
            echo "Failed to unmount $directory. Check if it's in use."
            return 1
        fi
    else
        echo "Directory $directory is not a mount point."
    fi
}

# Function to stop mdadm arrays
stop_mdadm_arrays() {
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

# Unmount any mounted partitions
unmount_if_mounted /mnt/boot
unmount_if_mounted /mnt/home
unmount_if_mounted /mnt
# Stop mdadm arrays
stop_mdadm_arrays "${disks[@]}"

echo "ALERT! About to wipe and reformat the following disks:"
echo "       ${disks[@]}"
echo "       Do you want to continue?"
echo "       This is a destructive operation!"
echo
read -p "Are you sure? [y/N]" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Loop over each disk device
    for disk in "${disks[@]}"; do
        echo "Wiping $disk..."

        # Wipe filesystem signatures using wipefs
        wipefs --all --force "$disk"

        # Wipe the beginning and end of the disk to remove partition table and RAID metadata
        dd if=/dev/zero of="$disk" bs=1M count=10
        dd if=/dev/zero of="$disk" bs=1M count=10 seek=$(( `blockdev --getsz "$disk"` - 20))

        echo "$disk has been wiped."
    done
    echo "All specified disks have been wiped."
    sync

    echo "Creating new partition table on /dev/vda..."
    parted /dev/vda -- mklabel gpt
    parted /dev/vda -- mkpart ESP fat32 1MiB 512MiB
    parted /dev/vda -- set 1 esp on
    parted /dev/vda -- set 1 boot on
    parted /dev/vda -- mkpart primary linux-swap 512MiB 1536MiB
    parted /dev/vda -- mkpart primary 1536MiB 100%

    mkfs.fat -F 32 -n ESP /dev/vda1
    mkswap -f /dev/vda2 --label swap
    # --encrypted --compression=lz4:0 --discard
    keyctl link @u @s
    bcachefs format -f --fs_label=root --label=root --encrypted /dev/vda3
    # check if the device is already unlocked
    if bcachefs unlock -c /dev/disk/by-label/root; then
        bcachefs unlock /dev/disk/by-label/root
    fi

    mount -o relatime,nodiratime /dev/disk/by-label/root /mnt
    mkdir /mnt/boot
    mount -o umask=0077 /dev/disk/by-label/ESP /mnt/boot
else
    echo "Aborting."
fi
