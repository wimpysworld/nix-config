{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
in
lib.mkIf (host.is.workstation && host.is.linux) {
  home.packages = [
    pkgs.libreoffice
  ];
}
