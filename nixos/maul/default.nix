{
  config,
  inputs,
  lib,
  pkgs,
  username,
  ...
}:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    ./disks.nix
  ];

  boot = {
    initrd = {
      availableKernelModules = [
        "nvme"
        "ahci"
        "xhci_pci"
        "usbhid"
        "uas"
        "usb_storage"
        "sd_mod"
      ];

      # Configure the LUKS devices for the initrd.
      luks = {
        # Pass options to systemd-cryptsetup in the initrd.
        # This tells it to look for a FIDO2 device and gives it a 30-second
        # timeout before falling back to other methods (like a password prompt,
        # if one were configured as a fallback).
        devices."p0" = {
          crypttabExtraOpts = [
            "fido2-device=auto"
            "token-timeout=30"
          ];
        };
        devices."p1" = {
          crypttabExtraOpts = [
            "fido2-device=auto"
            "token-timeout=30"
          ];
        };
        devices."p2" = {
          crypttabExtraOpts = [
            "fido2-device=auto"
            "token-timeout=30"
          ];
        };
        devices."p3" = {
          crypttabExtraOpts = [
            "fido2-device=auto"
            "token-timeout=30"
          ];
        };
        # This is counter-intuitive but REQUIRED.
        # The native systemd-cryptenroll support replaces this older module.
        fido2Support = false;
      };
      kernelModules = [
        "kvm-amd"
        "nvidia"
      ];

      # Enable support for the Btrfs filesystem.
      supportedFilesystems = [ "btrfs" ];
      # Use the systemd-based initrd, which is required for modern
      # LUKS unlocking features like FIDO2.
      systemd.enable = true;
    };
  };

  hardware = {
    nvidia = {
      open = false;
      prime.offload.enable = false;
    };
  };

  services = {
    btrfs.autoScrub = {
      fileSystems = [ "/" ];
      enable = true;
      interval = "monthly";
    };
    xserver.videoDrivers = [
      "nvidia"
    ];
  };
}
