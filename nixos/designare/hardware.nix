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
    ../_mixins/services/pipewire.nix
  ];

  console = {
    earlySetup = true;
    # Pixel sizes of the font: 12, 14, 16, 18, 20, 22, 24, 28, 32
    # Followed by 'n' (normal) or 'b' (bold)
    font = "ter-powerline-v28n";
    packages = [ pkgs.terminus_font pkgs.powerline-fonts ];
  };

  swapDevices = [{
    device = "/swap";
    size = 2048;
  }];

  environment.systemPackages = with pkgs; [
    nvtop
    polychromatic
  ];

  hardware = {
    bluetooth.enable = true;
    bluetooth.settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
      };
    };
    mwProCapture.enable = true;
    nvidia = {
      prime = {
        amdgpuBusId = "PCI:3:0:0";
        nvidiaBusId = "PCI:4:0:0";
        # Make the Radeon RX6800 default. The NVIDIA T600 is on for CUDA/NVENC
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
