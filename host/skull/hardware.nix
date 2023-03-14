# Intel Skull Canyon NUC6i7KYK
{ config, lib, pkgs, ... }:
{
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

  hardware = {
    bluetooth.enable = true;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
