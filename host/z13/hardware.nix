{ config, lib, pkgs, ... }:
{
  imports = [
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

  swapDevices = [{
    device = "/swap";
    size = 2048;
  }];

  hardware = {
    bluetooth.enable = true;
    bluetooth.settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
      };
    };
    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
