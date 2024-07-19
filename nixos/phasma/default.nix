{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-gpu-amd
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    ./disks.nix
    ./disks-home.nix
    ./disks-snapshot.nix
  ];

  # TODO: Remove this if/when machine is reinstalled.
  # This is a workaround for the legacy -> gpt tables disko format.
  fileSystems = {
    "/".device = lib.mkForce "/dev/disk/by-partlabel/root";
    "/boot".device = lib.mkForce "/dev/disk/by-partlabel/ESP";
  };

  boot = {
    initrd.availableKernelModules = [
      "nvme"
      "ahci"
      "xhci_pci"
      "usbhid"
      "uas"
      "sd_mod"
    ];
    kernelModules = [
      "amdgpu"
      "kvm-amd"
      "nvidia"
    ];
    kernelPackages = lib.mkForce pkgs.linuxPackages_latest;
    kernelParams = [
      # Disable USB autosuspend on workstations
      "usbcore.autosuspend=-1"
      "video=DP-1:3440x1440@60"
      "video=DP-2:1920x1080@60"
      "video=HDMI-A-1:1920x1080@60"
    ];
    swraid = {
      enable = true;
      mdadmConf = "PROGRAM=true";
    };
  };

  hardware = {
    mwProCapture.enable = true;
    nvidia = {
      prime = {
        amdgpuBusId = "PCI:34:0:0";
        nvidiaBusId = "PCI:31:0:0";
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        # Make the Radeon RX6700 XT default; the NVIDIA T600 is for CUDA/NVENC
        reverseSync.enable = true;
      };
    };
    xone.enable = true;
  };
  services.xserver.videoDrivers = [
    "amdgpu"
    "nvidia"
  ];
}
