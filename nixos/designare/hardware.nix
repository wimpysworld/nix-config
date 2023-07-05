# Motherboard: Gigabye Z390 Designare
# CPU:         Intel i9 9900K
# GPU:         Radeon RX6800
# GPU:         NVIDIA T600
# CAP:         Magewell Pro Capture Dual HDMI 11080
# RAM:         128GB DDR4
# NVME:        512GB Samsung 960 Pro
# NVME:        2TB Samsung 960 Pro
# Storage:     Sedna PCIe Dual 2.5 Inch SATA III (6G) SSD Adapter
# SATA:        1TB SanDisk SSD Plus
# SATA:        1TB SanDisk SSD Plus

{ config, inputs, lib, pkgs, username, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-gpu-amd
    inputs.nixos-hardware.nixosModules.common-gpu-intel
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    ../_mixins/services/bluetooth.nix
    ../_mixins/services/pipewire.nix
  ];

  swapDevices = [{
    device = "/swap";
    size = 2048;
  }];

  environment.systemPackages = with pkgs; [
    nvtop
    polychromatic
  ];

  hardware = {
    mwProCapture.enable = true;
    nvidia = {
      prime = {
        amdgpuBusId = "PCI:3:0:0";
        nvidiaBusId = "PCI:4:0:0";
        # Make the Radeon RX6800 default. The NVIDIA T600 is for CUDA/NVENC
        reverseSync.enable = true;
      };
      nvidiaSettings = false;
    };
    openrazer = {
      enable = true;
      devicesOffOnScreensaver = false;
      keyStatistics = true;
      mouseBatteryNotifier = true;
      syncEffectsEnabled = true;
      users = [ "${username}" ];
    };
    xone.enable = true;
  };

  services = {
    hardware.openrgb = {
      enable = true;
      motherboard = "intel";
      package = pkgs.openrgb-with-all-plugins;
    };
    xserver.videoDrivers = [
      "amdgpu"
      "nvidia"
    ];
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
