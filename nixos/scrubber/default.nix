{ lib, modulesPath, pkgs, platform, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    (import ./disks.nix { })
    ../_mixins/kernel/bcachefs.nix
    ../_mixins/services/pipewire.nix
  ];

  boot = {
    initrd.availableKernelModules = [ "xhci_pci" "ohci_pci" "ehci_pci" "virtio_pci" "ahci" "usbhid" "sr_mod" "virtio_blk" ];
  };
  nixpkgs.hostPlatform = lib.mkDefault "${platform}";
}
