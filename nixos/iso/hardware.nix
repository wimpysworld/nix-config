{ lib, modulesPath, pkgs, ... }:
{
  imports = [
    ../_mixins/services/pipewire.nix
  ];

  console = {
    # Pixel sizes of the font: 12, 14, 16, 18, 20, 22, 24, 28, 32
    # Followed by 'n' (normal) or 'b' (bold)
    font = "ter-powerline-v18n";
  };

  environment.systemPackages = with pkgs; [ ];

  services = {
    xserver.videoDrivers = [ ];
  };
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
