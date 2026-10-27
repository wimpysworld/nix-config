{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  compositor =
    if host.is.linux && host.is.workstation then
      lib.attrByPath [
        host.desktop
      ] null (import ../../../../../../lib/wayland-compositors.nix).compositors
    else
      null;
  sessionTarget = if compositor == null then "graphical-session.target" else compositor.sessionTarget;
  batteryRefreshRate = pkgs.writeShellApplication {
    name = "battery-refresh-rate";
    runtimeInputs = with pkgs; [
      coreutils
      jq
      systemd
      wlr-randr
    ];
    text = builtins.readFile ./battery-refresh-rate.sh;
  };
in
lib.mkIf (host.is.linux && host.is.workstation && host.is.laptop && compositor != null) {
  # Switch high-refresh internal laptop panels to 60 Hz on battery and back to
  # their highest refresh rate for the active resolution on AC power. The
  # helper queries and updates live wlr-output-management modes without
  # generating compositor output rules or kanshi profiles from the registry.
  systemd.user.services.battery-refresh-rate = {
    Unit = {
      Description = "Switch laptop internal panel refresh rate on AC and battery";
      After = [
        sessionTarget
        "kanshi.service"
      ];
      PartOf = [ sessionTarget ];
    };
    Service = {
      ExecStart = lib.getExe batteryRefreshRate;
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ sessionTarget ];
  };
}
