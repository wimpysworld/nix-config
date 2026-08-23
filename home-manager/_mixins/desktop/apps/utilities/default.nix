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

  systemd.user.services.lan-mouse.Install.WantedBy = lib.mkIf (host.desktop == "wayfire") (
    lib.mkForce [ "wayfire-session.target" ]
  );
}
