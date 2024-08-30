{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
{
  # TODO: There is an issue where the LED light on the mic button is always on.
  # - https://wiki.archlinux.org/title/Lenovo_ThinkPad_T14_(AMD)_Gen_3#Mute_Mic_LED_always_on
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
    inputs.nixos-hardware.nixosModules.common-gpu-amd
    inputs.nixos-hardware.nixosModules.common-pc-ssd
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
    # Force use of the thinkpad_acpi driver for backlight control.
    # This allows the backlight save/load systemd service to work.
    # Thinkpad T14s AMD Gen 1 does not wake up from suspend using 'deep' sleep.
    kernelParams = [
      "acpi_backlight=native"
      "mem_sleep_default=s2idle"
    ];
  };

  hardware = {
    trackpoint = {
      enable = lib.mkDefault true;
      emulateWheel = lib.mkDefault config.hardware.trackpoint.enable;
    };
  };
  services.fprintd.enable = lib.mkDefault true;
}
