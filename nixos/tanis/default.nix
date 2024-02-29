{ inputs, lib, pkgs, platform, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-z13
    ./disks.nix
    ../_mixins/kernel/bcachefs.nix
    ../_mixins/services/filesync.nix
    ../_mixins/services/tailscale.nix
  ];

  # FIXME: Wake from suspend regression in Linux 6.7 and 6.8
  # Use pkgs.linuxPackages_6_6 until it's fixed, which means a re-install because I'm using bacahefs
  # - https://bbs.archlinux.org/viewtopic.php?id=291136
  # - https://bugzilla.kernel.org/show_bug.cgi?id=217239

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
}
