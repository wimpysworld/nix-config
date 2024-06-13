{ hostname, lib, pkgs, ... }:
{
  imports = lib.optional (builtins.pathExists (./. + "/${hostname}.nix")) ./${hostname}.nix;
  services = {
    netdata = {
      enable = true;
      enableAnalyticsReporting = false;
      package = pkgs.netdata;
    };
  };
}
