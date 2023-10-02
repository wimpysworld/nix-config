{ lib, platform, ... }:
{
  imports = [
    ../_mixins/services/bluetooth.nix
    ../_mixins/services/pipewire.nix
  ];
  nixpkgs.hostPlatform = lib.mkDefault "${platform}";
}
