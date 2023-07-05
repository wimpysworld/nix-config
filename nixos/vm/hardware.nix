{ lib, modulesPath, pkgs, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ../_mixins/services/pipewire.nix
  ];

  swapDevices = [{
    device = "/swap";
    size = 1024;
  }];

  environment.systemPackages = with pkgs; [ ];

  services = {
    xserver.videoDrivers = [ ];
  };
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
