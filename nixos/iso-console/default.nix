{ lib, platform, ... }:
{
  nixpkgs.hostPlatform = lib.mkDefault "${platform}";
}
