{ lib, pkgs, ... }:
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

  # Workaround for Failed to restart syncthingtray.service: Unit tray.target not found.
  # - https://github.com/nix-community/home-manager/issues/2064
  systemd.user.targets.tray = lib.mkIf isLinux {
    Unit = {
      Description = "Home Manager System Tray";
      Wants = [ "graphical-session-pre.target" ];
    };
  };
}
