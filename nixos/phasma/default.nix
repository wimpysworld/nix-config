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
    kernelPackages = lib.mkForce pkgs.linuxPackages_6_11;
    kernelParams = [
      "video=DP-1:3440x1440@100"
      "video=DP-2:1920x1080@60"
      "video=HDMI-A-1:2560x1600@120"
    ];
    swraid = {
      enable = true;
      mdadmConf = "MAILADDR=${username}@wimpys.world";
    };
  };

  hardware = {
    mwProCapture.enable = true;
    nvidia = {
      open = false;
      prime = {
        amdgpuBusId = "PCI:34:0:0";
        nvidiaBusId = "PCI:31:0:0";
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        # Make the Radeon RX 7900 GRE default; the RTX 2000E Ada Generation is for CUDA/NVENC
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
