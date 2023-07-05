{ lib, modulesPath, pkgs, ... }:
{
  imports = [
    ../_mixins/services/bluetooth.nix
    ../_mixins/services/pipewire.nix
  ];

  environment.systemPackages = with pkgs; [ ];

  services = {
    xserver.videoDrivers = [ ];
  };
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
