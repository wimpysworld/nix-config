{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf (config.noughty.host.is.linux && config.noughty.host.is.workstation) {
  home.packages = [ pkgs.rustdesk-flutter ];
}
