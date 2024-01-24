{ lib, modulesPath, pkgs, platform, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    (import ./disks.nix { })
    ../_mixins/linux/latest.nix
    ../_mixins/hardware/systemd-boot.nix
    ../_mixins/services/pipewire.nix
  ];

  # disko does manage mounting, but I want to mount by-label
  fileSystems."/" = lib.mkForce {
    device = "/dev/disk/by-label/root";
    fsType = "bcachefs";
    options = [ "defaults" "relatime" "nodiratime" ];
  };

  fileSystems."/boot" = lib.mkForce {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
  };

  swapDevices = lib.mkForce [{
    device = "/dev/disk/by-label/swap";
  }];

  boot = {
    initrd.availableKernelModules = [ "xhci_pci" "ohci_pci" "ehci_pci" "virtio_pci" "ahci" "usbhid" "sr_mod" "virtio_blk" ];
  };
  nixpkgs.hostPlatform = lib.mkDefault "${platform}";
}
