{
  config,
  inputs,
  lib,
  ...
}:
{
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
      "usb_storage"
      "rtsx_pci_sdmmc"
    ];
    initrd.systemd.enable = true;
    kernelModules = [
      "amdgpu"
      "kvm-amd"
    ];
    # Force use of the thinkpad_acpi driver for backlight control.
    # This allows the backlight save/load systemd service to work.
    kernelParams = [
      "acpi_backlight=native"
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
