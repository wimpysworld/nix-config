{ pkgs, ... }:
let
  inherit (pkgs.stdenv) isLinux;
in
{
  services.syncthing = {
    tray = {
      enable = isLinux;
      package = pkgs.syncthingtray;
    };
  };
}
