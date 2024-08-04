{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t14s-amd-gen1
    ./disks.nix
  ];

  boot = {
    initrd.availableKernelModules = [
      "nvme"
      "ehci_pci"
      "xhci_pci"
      "uas"
      "sd_mod"
      "rtsx_pci_sdmmc"
    ];
    initrd.systemd.enable = true;
    kernelModules = [
      "amdgpu"
      "kvm-amd"
    ];
    kernelPackages = lib.mkForce pkgs.linuxPackages_latest;
    kernelParams = [ "mem_sleep_default=s2idle" ];
  };

  services.fprintd.enable = lib.mkDefault true;
}
