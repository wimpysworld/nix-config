# Motherboard:       Gigabyye B360 HD3P-LM Ultra Durable
# CPU:               Intel i7 8700
# GPU:               Intel UHD Graphics 630
# RAM:               128GB DDR4
# NVME0:             512GB Samsung PM9A1 M.2 SSD NVMe (PCIe 4.0 x4) MZVL2512HCJQ-00B00
# SATA1:             8TB Ultrastar DC HC510 7200RPM (SATA 3.2) HUH721008ALE600
# SATA2:             8TB Ultrastar DC HC510 7200RPM (SATA 3.2) HUH721008ALE600
{
  hostname,
  inputs,
  lib,
  pkgs,
  username,
  ...
}:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-gpu-intel
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    ./disks.nix
    ./disks-data.nix
  ];

  boot = {
    initrd.availableKernelModules = [
      "ahci"
      "nvme"
      "sd_mod"
      "xhci_pci"
    ];
    kernelModules = [
      "kvm-intel"
    ];
    # Using GRUB because malak has no EFI boot available
    loader = {
      grub = {
        enable = true;
      };
      systemd-boot.enable = lib.mkForce false;
    };
    swraid = {
      enable = true;
      mdadmConf = "PROGRAM=true";
    };
  };

  # Something is enabling Samba; so disable it while I figure out what
  services.samba.enable = lib.mkForce false;
  services.samba-wsdd.enable = lib.mkForce false;
}
