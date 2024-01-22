{ lib, platform, ... }:
{
  imports = [
    ../_mixins/linux/latest.nix
  ];
  nixpkgs.hostPlatform = lib.mkDefault "${platform}";
}
