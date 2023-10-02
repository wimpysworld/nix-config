{ lib, platform, ... }:
{
  imports = [
    ../_mixins/services/bluetooth.nix
    ../_mixins/services/pipewire.nix
    ../_mixins/hardware/gpd-win-max.nix
  ];
  nixpkgs.hostPlatform = lib.mkDefault "${platform}";
}
