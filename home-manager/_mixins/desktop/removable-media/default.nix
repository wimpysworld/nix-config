# Automounts removable drives through UDisks2 in the user session. udiskie
# sends a desktop notification when a drive is added, mounted, unmounted or
# removed. It uses only D-Bus, so it works with every compositor and on generic
# Linux hosts where the distribution provides UDisks2 and polkit.
{ config, lib, ... }:
let
  inherit (config.noughty) host;
  compositor =
    if host.is.linux && host.is.workstation then
      lib.attrByPath [ host.desktop ] null (import ../../../../lib/wayland-compositors.nix).compositors
    else
      null;
  sessionTarget = if compositor == null then "graphical-session.target" else compositor.sessionTarget;
in
lib.mkIf (host.is.linux && host.is.workstation) {
  services.udiskie = {
    enable = true;
    automount = lib.mkDefault true;
    notify = lib.mkDefault true;
    tray = "never";
    # Ignore an empty card reader, so that it sends no notification. A partition
    # reports no media of its own, so the rule must match only top-level drives.
    # Loop devices also report no media, so the rule leaves them to the
    # built-in rules.
    settings.device_config = [
      {
        is_toplevel = true;
        is_loop = false;
        has_media = false;
        ignore = true;
      }
    ];
  };

  systemd.user.services.udiskie = {
    Unit = {
      After = lib.mkForce [ sessionTarget ];
      PartOf = lib.mkForce [ sessionTarget ];
    };
    # The Home Manager module adds --appindicator when
    # xsession.preferStatusNotifierItems is true, and udiskie then shows a tray
    # icon even when the config file sets tray to false. Start udiskie with no
    # flags, so that it reads automount, notify and tray from config.yml.
    Service.ExecStart = lib.mkForce (lib.getExe' config.services.udiskie.package "udiskie");
    Install.WantedBy = lib.mkForce [ sessionTarget ];
  };
}
