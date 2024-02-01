{ desktop, lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    maestral
  ] ++ lib.optionals (desktop != null) [
    celeste
    maestral-gui
  ];

  systemd.user.services.maestral = {
    description = "Maestral";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.maestral}/bin/maestral start";
      ExecReload = "${pkgs.util-linux}/bin/kill $MAINPID";
      KillMode = "process";
      Restart = "on-failure";
    };
  };
}
