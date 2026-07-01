# Modern Unix `man`
# Use the Rust client for tldr
# https://github.com/tldr-pages/tlrc
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
in
{
  home.packages = lib.optionals (!host.is.server) [
    pkgs.tlrc
  ];
  services = {
    tldr-update = lib.mkIf host.is.workstation {
      enable = true;
      package = pkgs.tlrc;
    };
  };
}
