{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  compositor = lib.attrByPath [
    host.desktop
  ] null (import ../../../../../lib/wayland-compositors.nix).compositors;
in
lib.mkIf (noughtyLib.isUser [ "martin" ] && host.is.workstation && host.is.linux) {
  home.packages = with pkgs; [
    cpu-x
    gnome-firmware
    usbimager
    vaults
  ];

  programs.lan-mouse.enable = true;

  systemd.user.services.lan-mouse = lib.mkIf (compositor != null) {
    Unit.PartOf = [ compositor.sessionTarget ];
    Install.WantedBy = lib.mkForce [ compositor.sessionTarget ];
  };
}
