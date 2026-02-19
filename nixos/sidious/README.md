# sidious

ThinkPad P1 Gen 1 dual-boot configuration. NixOS and Windows 11 Pro are installed on separate disks.

## Windows Boot Manager on multi-disk systems

The Windows EFI partition is not automatically detected by systemd-boot because it is on a different disk. The following steps copy the Windows Boot Manager to the NixOS EFI partition so dual-booting is possible.

Find Windows EFI Partition

```shell
lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT
```

Mount Windows EFI Partition

```shell
sudo mkdir /mnt/win-efi
sudo mount /dev/nvme1n1p1 /mnt/win-efi
```

Copy Contents of Windows EFI to NixOS EFI

```shell
sudo rsync -av /mnt/win-efi/EFI/Microsoft/ /boot/EFI/Microsoft/
```

Clean up

```shell
sudo umount /mnt/win-efi
sudo rm -rf /mnt/win-efi
```

Reboot and systemd-boot should now offer the option to boot NixOS and Windows.
