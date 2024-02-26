{ inputs, lib, pkgs, platform, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-z13
    ./disks.nix
    ../_mixins/kernel/bcachefs.nix
    ../_mixins/hardware/gpu.nix
    ../_mixins/hardware/systemd-boot.nix
    ../_mixins/services/bluetooth.nix
    ../_mixins/services/filesync.nix
    ../_mixins/services/pipewire.nix
    ../_mixins/services/tailscale.nix
    ../_mixins/virt
  ];

  boot = {
    initrd = {
      availableKernelModules = [
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
    };
    kernelModules = [ "amdgpu" "kvm-amd" ];
  };

  services.kmscon.extraConfig = lib.mkForce ''
    font-size=18
    xkb-layout=gb
  '';
  nixpkgs.hostPlatform = lib.mkDefault "${platform}";
}
