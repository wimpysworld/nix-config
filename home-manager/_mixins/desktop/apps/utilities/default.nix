{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
in
lib.mkIf (noughtyLib.isUser [ "martin" ] && host.is.workstation && host.is.linux) {
  home.packages = with pkgs; [
    cpu-x
    gnome-firmware
    usbimager
    vaults
  ];

  programs.lan-mouse.enable = true;
}
