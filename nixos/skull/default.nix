# Intel Skull Canyon NUC6i7KYK
{ config, inputs, lib, pkgs, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    ../_mixins/hardware/systemd-boot.nix
    ../_mixins/services/bluetooth.nix
    ../_mixins/services/zerotier.nix
    ../_mixins/virt
  ] ++ (import ./disks.nix { });

  swapDevices = [{
    device = "/swap";
    size = 2048;
  }];

  boot = {
    initrd.availableKernelModules = [
        "ahci"
        "nvme"
        "rtsx_pci_sdmmc"
        "sd_mod"
        "sdhci_pci"
        "uas"
        "usbhid"
        "usb_storage"
        "xhci_pci"
      ];
    kernelModules = [ "kvm-intel" ];
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
