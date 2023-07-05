{ config, inputs, lib, pkgs, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.gpd-micropc
    ../_mixins/services/bluetooth.nix
    ../_mixins/services/pipewire.nix
  ];

  swapDevices = [{
    device = "/swap";
    size = 2048;
  }];

  # My GPD MicroPC has a US keyboard layout
  console = {
    keyMap = lib.mkForce "us";
  };

  environment.systemPackages = with pkgs; [
    nvtop-amd
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  services.kmscon.extraOptions = lib.mkForce "--xkb-layout=us";
  services.xserver.layout = lib.mkForce "us";
}
