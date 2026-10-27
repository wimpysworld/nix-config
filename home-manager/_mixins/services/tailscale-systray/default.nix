{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  sessionTarget = config.wayland.systemd.target;
in
lib.mkIf (host.is.linux && host.is.workstation && sessionTarget != "") {
  # Run the Tailscale systray as a user service on workstations, bound to
  # the graphical session so it starts and stops with the desktop environment
  systemd.user.services.tailscale-systray = {
    Unit = {
      Description = "Tailscale system tray";
      After = [ sessionTarget ];
      PartOf = [ sessionTarget ];
    };
    Service = {
      ExecStart = "${pkgs.tailscale}/bin/tailscale systray";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ sessionTarget ];
    };
  };
}
