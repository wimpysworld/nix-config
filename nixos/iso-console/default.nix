{ lib, platform, ... }:
{
  imports = [
    ../_mixins/kernel/bcachefs.nix
  ];
  nixpkgs.hostPlatform = lib.mkDefault "${platform}";
}
