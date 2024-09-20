{
  config,
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
    kernelParams = [
      "video=DP-1:3440x1440@100"
      "video=DP-2:1920x1080@60"
      "video=HDMI-A-1:2560x1600@120"
    ];
    swraid = {
      enable = true;
      mdadmConf = "PROGRAM=true";
    };
  };

  hardware = {
    mwProCapture.enable = true;
    nvidia = {
      # NVIDIA driver FTBFS with Linux 6.10 (upgrade-hint)
      # https://github.com/NixOS/nixpkgs/issues/332350
      # https://github.com/NVIDIA/open-gpu-kernel-modules/issues/642
      # https://discourse.nixos.org/t/builder-for-nvidia-x11-550-78-6-10-drv-failed-with-exit-code-2/49360
      package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
        version = "555.58.02";
        sha256_64bit = "sha256-xctt4TPRlOJ6r5S54h5W6PT6/3Zy2R4ASNFPu8TSHKM=";
        sha256_aarch64 = "sha256-wb20isMrRg8PeQBU96lWJzBMkjfySAUaqt4EgZnhyF8=";
        openSha256 = "sha256-8hyRiGB+m2hL3c9MDA/Pon+Xl6E788MZ50WrrAGUVuY=";
        settingsSha256 = "sha256-ZpuVZybW6CFN/gz9rx+UJvQ715FZnAOYfHn5jt5Z2C8=";
        persistencedSha256 = "sha256-a1D7ZZmcKFWfPjjH1REqPM5j/YLWKnbkP9qfRyIyxAw=";
      };
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
