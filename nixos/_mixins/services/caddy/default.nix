{ hostname, lib, pkgs, ... }:
{
  imports = lib.optional (builtins.pathExists (./. + "/${hostname}.nix")) ./${hostname}.nix;
  services.caddy.enable = false;
}
