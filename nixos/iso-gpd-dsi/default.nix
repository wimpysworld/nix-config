{ lib, platform, ... }:
{
  # Pocket, Pocket 3, MicroPC, Win 3, TopJoy Falcon
  imports = [
    ../_mixins/services/bluetooth.nix
    ../_mixins/services/pipewire.nix
    ../_mixins/hardware/gpd-dsi.nix
  ];
  nixpkgs.hostPlatform = lib.mkDefault "${platform}";
}
