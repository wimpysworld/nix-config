{ lib, platform, ... }:
{
  # Pocket 2, Win 2, Win Max
  imports = [
    ../_mixins/services/bluetooth.nix
    ../_mixins/services/pipewire.nix
    ../_mixins/hardware/gpd-edp.nix
  ];
  nixpkgs.hostPlatform = lib.mkDefault "${platform}";
}
