{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  scanningApp = if (host.desktop == "plasma") then pkgs.kdePackages.skanpage else pkgs.simple-scan;
in
lib.mkIf (host.is.linux && host.is.workstation) {
  home.packages = [ scanningApp ];
}
