{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disks.nix
  ];

  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_blk"
  ];
}
