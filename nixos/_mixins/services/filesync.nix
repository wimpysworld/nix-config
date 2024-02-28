{ desktop, lib, pkgs, ... }:
let
  isWorkstation = if (desktop != null) then true else false;
in
{
  environment.systemPackages = with pkgs; [
    maestral
  ] ++ lib.optionals (isWorkstation) [
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
