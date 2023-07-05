{ config, inputs, lib, pkgs, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.gpd-p2-max
    ../_mixins/services/pipewire.nix
  ];

  swapDevices = [{
    device = "/swap";
    size = 2048;
  }];

  # My GPD P2 Max has a US keyboard layout
  console = {
    # Pixel sizes of the font: 12, 14, 16, 18, 20, 22, 24, 28, 32
    # Followed by 'n' (normal) or 'b' (bold)
    font = "ter-powerline-v28n";
    keyMap = lib.mkForce "us";
  };

  environment.systemPackages = with pkgs; [
    nvtop-amd
  ];

  hardware = {
    bluetooth.enable = true;
    bluetooth.settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
      };
    };
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  services.xserver.layout = lib.mkForce "us";
}
