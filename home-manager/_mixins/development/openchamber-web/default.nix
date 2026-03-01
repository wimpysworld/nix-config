# OpenChamber Web - browser-based GUI for the OpenCode AI coding agent.
# Runs a local web server and provides a PWA-style desktop entry via Chromium.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  port = 3210;
in
lib.mkIf (host.is.workstation && host.is.linux) {
  home.packages = [
    pkgs.openchamber-web
  ];

  # Run the OpenChamber web server as a background service.
  systemd.user.services.openchamber-web = {
    Unit = {
      Description = "OpenChamber Web - GUI for OpenCode AI agent";
      Documentation = "https://github.com/btriapitsyn/openchamber";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${lib.getExe pkgs.openchamber-web} --port ${toString port}";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # Desktop entry launches Chromium in app mode pointing at the local server.
  xdg.desktopEntries.openchamber-web = {
    name = "OpenChamber";
    genericName = "AI Coding Agent GUI";
    comment = "Web interface for the OpenCode AI coding agent";
    exec = "${lib.getExe pkgs.chromium} --app=http://localhost:${toString port}";
    icon = "applications-development";
    terminal = false;
    type = "Application";
    categories = [
      "Development"
      "IDE"
      "WebBrowser"
    ];
    startupNotify = true;
    settings = {
      StartupWMClass = "chromium-browser";
    };
  };
}
