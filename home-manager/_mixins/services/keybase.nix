{ config, desktop, lib, pkgs, username, ... }:
let
  inherit (pkgs.stdenv) isLinux;
  isWorkstation = if (desktop != null) then true else false;
in
lib.mkIf isLinux {
  home.packages = with pkgs; [
    keybase
  ] ++ lib.optionals (isWorkstation) [
    keybase-gui
  ];
  services = {
    kbfs = {
      enable = true;
      extraFlags = [ "-label ${username}-KBFS" "-mode=minimal" ];
      mountPoint = "Keybase";
    };
    keybase = {
      enable = true;
    };
  };
}
