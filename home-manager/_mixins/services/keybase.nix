{ config, desktop, lib, pkgs, username, ... }:
let
  inherit (pkgs.stdenv) isLinux;
in
lib.mkIf isLinux {
  home.packages = with pkgs; [
    keybase
  ] ++ lib.optionals (desktop != null) [
    keybase-gui
  ];
  services = {
    kbfs = {
      enable = isLinux;
      extraFlags = [ "-label ${username}-KBFS" "-mode=minimal" ];
      mountPoint = "Keybase";
    };
    keybase = {
      enable = isLinux;
    };
  };
}
