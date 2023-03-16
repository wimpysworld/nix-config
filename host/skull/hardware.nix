# Intel Skull Canyon NUC6i7KYK
{ config, lib, pkgs, ... }:
{
  # TODO: Replace this with disko
  fileSystems."/" = {
    device = "/dev/disk/by-label/root";
    fsType = "xfs";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-label/home";
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
