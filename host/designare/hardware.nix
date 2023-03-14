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

{ config, lib, pkgs, modulesPath, username, ... }:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ../_mixins/services/pipewire.nix
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/ROOT";
    fsType = "xfs";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-label/HOME";
    fsType = "xfs";
  };

  swapDevices = [{
    device = "/swap";
    size = 2048;
  }];

  environment.systemPackages = with pkgs; [
    nvtop
  ];

  hardware = {
    bluetooth.enable = true;
    bluetooth.settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
      };
    };
    #error: Package ‘mwprocapture-1.3.0.4236-6.2.3’ is marked as broken, refusing to evaluate.
    mwProCapture.enable = false;
    nvidia = {
      prime = {
        amdgpuBusId = "PCI:3:0:0";
        nvidiaBusId = "PCI:4:0:0";
        # The NVIDIA T600 is for CUDA/NVENC only
        reverseSync.enable = true;
      };
      nvidiaSettings = true;
    };
    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };
    openrazer = {
      enable = true;
      devicesOffOnScreensaver = false;
      keyStatistics = true;
      mouseBatteryNotifier = true;
      syncEffectsEnabled = true;
      users = [ "${username}" ];
    };
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
