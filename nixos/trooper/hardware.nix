# Motherboard: ROG Crosshair VIII Impact
# CPU:         AMD Ryzen 9 5950X
# GPU:         NVIDIA RTX 3080Ti
# RAM:         64GB DDR4
# NVME:        2TB Corsair MP600
# NVME:        4TB Corsair MP600
# SATA:        4TB Samsung 870 QVO
# SATA:        4TB Samsung 870 QVO

{ config, inputs, lib, pkgs, username, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    ../_mixins/services/pipewire.nix
  ];

  console = {
    earlySetup = true;
    # Pixel sizes of the font: 12, 14, 16, 18, 20, 22, 24, 28, 32
    # Followed by 'n' (normal) or 'b' (bold)
    font = "ter-powerline-v18n";
    packages = [ pkgs.terminus_font pkgs.powerline-fonts ];
  };

  # UUID=ac6a2f42-bf5b-42bf-bbb2-2bb83a6af615 /mnt/snapshot auto defaults,x-parent=0f904a98:9d3109df:867172aa:c68c98f0 0 0
  fileSystems."/mnt/snapshot" = {
    device = "/dev/disk/by-label/snapshot";
    fsType = "xfs";
  };

  swapDevices = [{
    device = "/swap";
    size = 2048;
  }];

  environment.systemPackages = with pkgs; [
    nvtop-nvidia
    polychromatic
  ];

  hardware = {
    bluetooth.enable = true;
    bluetooth.settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
      };
    };
    nvidia.prime.offload.enable = false;
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
    xone.enable = true;
  };

  services = {
    hardware.openrgb = {
      enable = true;
      motherboard = "amd";
      package = pkgs.openrgb-with-all-plugins;
    };
    xserver.videoDrivers = [
      "nvidia"
    ];
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
