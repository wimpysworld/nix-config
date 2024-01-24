#!/usr/bin/env bash

# NVME (root)
#/dev/disk/by-id/nvme-Corsair_MP600_CORE_212479080001303710B4 -> /          (2TB)    nvme0n1
#/dev/disk/by-id/nvme-CT4000P3PSSD8_2336E873DCBF              -> /          (4TB)    nvme1n1
#/dev/disk/by-id/nvme-Corsair_MP600_CORE_21177909000130384189 -> /          (4TB)    nvme2n1

# SSD (borg)
#/dev/disk/by-id/ata-TS4TMTS830S_H986540074                   -> /mnt/borg  (4TB)    sda
#/dev/disk/by-id/ata-TS4TMTS830S_H986540082                   -> /mnt/borg  (4TB)    sdb
#/dev/disk/by-id/ata-Samsung_SSD_870_QVO_4TB_S5STNG0R100684E  -> /mnt/borg  (4TB)    sdc

size_esp="768MiB"
size_swap="128GiB"

# Array of disk devices to be wiped
disks=(/dev/nvme0n1 \
       /dev/nvme1n1 \
       /dev/nvme2n1 \
       /dev/sda \
       /dev/sdb \
       /dev/sdc
      )

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
unmount_if_mounted /mnt/mnt/borg
unmount_if_mounted /mnt/boot
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
        echo "Wiping ${disk}..."

        # Wipe filesystem signatures using wipefs
        wipefs --all --force "${disk}"

        # Wipe the beginning and end of the disk to remove partition table and RAID metadata
        dd if=/dev/zero of="${disk}" bs=1M count=10
        dd if=/dev/zero of="${disk}" bs=1M count=10 seek=$(( `blockdev --getsz "${disk}"` - 20))

        echo "$disk has been wiped."
    done
    echo "All specified disks have been wiped."
    sync

    for disk in "${disks[@]}"; do
        case "${disk}" in
            /dev/nvme0n1)
                # Partition the first 2TB NVME
                parted "${disk}" -- mklabel gpt
                parted "${disk}" -- mkpart ESP fat32 2MiB "${size_esp}"
                parted "${disk}" -- set 1 esp on
                parted "${disk}" -- set 1 boot on
                parted "${disk}" -- mkpart primary linux-swap "${size_esp}" "${size_swap}"
                parted "${disk}" -- mkpart primary "${size_swap}" 100%
                ;;
            *)
                parted "${disk}" -- mklabel gpt
                parted "${disk}" -- mkpart primary 2MiB 100%
                ;;
        esac
    done

    mkfs.fat -F 32 -n ESP /dev/nvme0n1p1
    mkswap -f /dev/nvme0n1p2 --label swap

    echo "mkfs root"
    bcachefs format -f --fs_label=root --uuid=caf2a42b-ae3e-4e1d-bc1f-b9a881403b73 \
        --background_compression=lz4:0 \
        --compression=lz4:1 \
        --discard \
        --replicas=2 \
        --label=nvme.nvme0 /dev/nvme0n1p3 \
        --label=nvme.nvme1 /dev/nvme1n1p1 \
        --label=nvme.nvme2 /dev/nvme2n1p1
    # check if the encrypted device needs unlocking
    if bcachefs unlock -c /dev/disk/by-label/root; then
        # https://nixos.wiki/wiki/Bcachefs#NixOS_installation_on_bcachefs
        # https://github.com/NixOS/nixpkgs/issues/32279
        keyctl link @u @s
        bcachefs unlock /dev/disk/by-label/root
    fi

    mkfs.btrfs -f --label borg --uuid bef8c5bb-1fa6-4106-b546-0ebf1fc00c3a \
        /dev/sda1 /dev/sdb1 /dev/sdc1

    # mount the filesystems
    echo "mount root"
    bcachefs mount -o relatime,nodiratime,background_compression=lz4:0,compression=lz4:1,discard /dev/nvme0n1p3:/dev/nvme1n1p1:/dev/nvme2n1p1 /mnt
    sleep 1

    mkdir -p /mnt/boot
    echo "mount boot"
    mount -o umask=0077 /dev/disk/by-label/ESP /mnt/boot
    sleep 1

    mkdir -p /mnt/mnt/borg
    echo "mount borg"
    mount -t btrfs -o relatime,nodiratime,discard=async /dev/disk/by-label/borg /mnt/mnt/borg
    sleep 1
else
    echo "Aborting."
fi
