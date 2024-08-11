{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  # TODO: There is an issue where the LED light on the mic button is always on.
  # This udev rule will turn it off.
  # - https://wiki.archlinux.org/title/Lenovo_ThinkPad_T14_(AMD)_Gen_3#Mute_Mic_LED_always_on
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
    # Thinkpad T14s AMD Gen 1 does not wake up from suspend using 'deep' sleep.
    kernelParams = [ "mem_sleep_default=s2idle" ];
  };

  services.fprintd.enable = lib.mkDefault true;
}
