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
    # Force use of the thinkpad_acpi driver for backlight control.
    # This allows the backlight save/load systemd service to work.
    # Thinkpad T14s AMD Gen 1 does not wake up from suspend using 'deep' sleep.
    kernelParams = [
      "acpi_backlight=native"
    ];
  };

  # TODO: Remove when I migrate off bcachefs.
  environment.systemPackages = with pkgs; [
    bcachefs-tools
    keyutils
  ];

  hardware = {
    trackpoint = {
      enable = lib.mkDefault true;
      emulateWheel = lib.mkDefault config.hardware.trackpoint.enable;
    };
  };
  noughty.host.displays = [
    {
      output = "eDP-1";
      width = 1920;
      height = 1080;
      primary = true;
      workspaces = [
        1
        2
        3
        4
        5
        6
        7
        8
      ];
    }
  ];

  services.fprintd.enable = lib.mkDefault true;
}
