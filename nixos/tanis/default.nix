{ inputs, lib, pkgs, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-z13
    ./disks.nix
    ../_mixins/services/filesync.nix
    ../_mixins/services/tailscale.nix
  ];

  boot = {
    initrd = {
      availableKernelModules = [
        "nvme"
        "sd_mod"
        "thunderbolt"
        "uas"
        "xhci_pci"
      ];
    };
    kernelModules = [ "amdgpu" "kvm-amd" ];
    # Wake from suspend regression in Linux 6.7 and 6.8
    # Use pkgs.linuxPackages_6_6 until it's fixed
    # - https://bbs.archlinux.org/viewtopic.php?id=291136
    # - https://bugzilla.kernel.org/show_bug.cgi?id=217239
    kernelPackages = lib.mkForce pkgs.linuxPackages_6_6;
  };

  services.kmscon.extraConfig = lib.mkForce ''
    font-size=18
    xkb-layout=gb
  '';
}
