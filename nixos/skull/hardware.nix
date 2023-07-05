# Intel Skull Canyon NUC6i7KYK
{ config, inputs, lib, pkgs, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    ../_mixins/services/bluetooth.nix
  ];

  swapDevices = [{
    device = "/swap";
    size = 2048;
  }];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
