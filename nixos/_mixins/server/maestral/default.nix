{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  host = config.noughty.host;
in
lib.mkIf
  (noughtyLib.isHost [
    "bane"
    "phasma"
    "tanis"
    "revan"
    "sidious"
    "vader"
  ])
  {
    environment.systemPackages = with pkgs; [ maestral ];

    systemd.user.services.maestral = {
      description = "Maestral";
      wantedBy = [ "default.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.maestral}/bin/maestral start";
        ExecReload = "${pkgs.util-linux}/bin/kill -HUP $MAINPID";
        KillMode = "process";
        Restart = "on-failure";
      };
    };

    systemd.user.services.maestral-gui = lib.mkIf host.is.workstation {
      description = "Maestral GUI";
      wantedBy = [ "default.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.maestral-gui}/bin/maestral_qt";
        ExecReload = "${pkgs.util-linux}/bin/kill -HUP $MAINPID";
        KillMode = "process";
        Restart = "on-failure";
      };
    };
  }
