{
  hostname,
  isWorkstation,
  lib,
  pkgs,
  ...
}:
let
  # Declare which hosts have Maestral (Dropbox) enabled.
  installOn = [
    "phasma"
    "tanis"
    "revan"
    "sidious"
    "vader"
  ];
in
lib.mkIf (lib.elem "${hostname}" installOn) {
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

  systemd.user.services.maestral-gui = lib.mkIf isWorkstation {
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
