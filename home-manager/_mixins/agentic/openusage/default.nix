{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  enabled = noughtyLib.userHasTag "developer" && config.noughty.host.is.workstation;
  stateDir = "${config.xdg.stateHome}/openusage";
in
lib.mkIf enabled {
  home = {
    packages = [ pkgs.openusage ];
    sessionVariables = lib.mkIf (!config.xdg.enable) {
      XDG_STATE_HOME = config.xdg.stateHome;
    };
    file.".config/openusage/settings.json".text = builtins.toJSON {
      theme = "Catppuccin Mocha";
    };
  };

  systemd.user.services.openusage-telemetry = lib.mkIf config.noughty.host.is.linux {
    Unit.Description = "OpenUsage telemetry daemon";
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.openusage}/bin/openusage telemetry daemon run";
      Environment = [ (lib.escapeShellArg "XDG_STATE_HOME=${config.xdg.stateHome}") ];
      WorkingDirectory = config.home.homeDirectory;
      Restart = "always";
      RestartSec = 2;
    };
    Install.WantedBy = [ "default.target" ];
  };

  xdg.configFile."systemd/user/default.target.wants/openusage-telemetry.service" =
    lib.mkIf config.noughty.host.is.linux
      { force = true; };

  xdg.stateFile."openusage/.keep" = lib.mkIf config.noughty.host.is.darwin { text = ""; };
  launchd.agents.openusage-telemetry = lib.mkIf config.noughty.host.is.darwin {
    enable = true;
    config = {
      Label = "com.openusage.telemetryd";
      ProgramArguments = [
        "${pkgs.openusage}/bin/openusage"
        "telemetry"
        "daemon"
        "run"
      ];
      EnvironmentVariables = {
        HOME = config.home.homeDirectory;
        XDG_STATE_HOME = config.xdg.stateHome;
        PATH = "${config.home.profileDirectory}/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      };
      RunAtLoad = true;
      KeepAlive.Crashed = true;
      ThrottleInterval = 30;
      StandardOutPath = "${stateDir}/daemon.stdout.log";
      StandardErrorPath = "${stateDir}/daemon.stderr.log";
    };
  };
}
