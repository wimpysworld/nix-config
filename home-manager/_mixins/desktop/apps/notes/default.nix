{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
in
lib.mkIf (host.is.linux && host.is.workstation) {
  home.packages = [ pkgs.manuscript ];
}
