#!/usr/bin/env bash

echo "$(basename ${0}) is disabled by default to prevent accidents! Quitting."
exit 1

# If the automated zap and create fails, the drives can be nuked with
# - https://bobcares.com/blog/removal-of-mdadm-raid-devices/
sudo mdadm --stop /dev/md125
sudo mdadm --stop /dev/md126
sudo mdadm --stop /dev/md127
sudo mdadm --remove /dev/md125
sudo mdadm --remove /dev/md126
sudo mdadm --remove /dev/md127
sudo mdadm --zero-superblock \
 /dev/sda1 \
 /dev/sdb1 \
 /dev/sdc1 \
 /dev/sdd1 \
 /dev/sde1 \
 /dev/sdf1 \
 /dev/sdg1 \
 /dev/sdh1 \
 /dev/sdi1 \
 /dev/sdj1 \
 /dev/sdk1

sudo sgdisk --zap-all \
 /dev/sda \
 /dev/sdb \
 /dev/sdc \
 /dev/sdd \
 /dev/sde \
 /dev/sdf \
 /dev/sdg \
 /dev/sdh \
 /dev/sdi \
 /dev/sdj \
 /dev/sdk
