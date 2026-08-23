{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  sessionTarget = config.wayland.systemd.target;
in
lib.mkIf (noughtyLib.hostHasTag "reframe" && config.noughty.host.is.workstation) {
  # ReFrame synchronises clipboard text through reframe-session, which must
  # run inside the graphical session. The NixOS mixin strips the package's
  # XDG autostart file, so this user service replaces it and binds the
  # daemon to the session lifetime. It reads the session socket in
  # /run/reframe-session, which requires membership of the reframe group.
  systemd.user.services.reframe-session = {
    Unit = {
      Description = "ReFrame clipboard synchronisation";
      After = [ sessionTarget ];
      PartOf = [ sessionTarget ];
    };
    Service = {
      ExecStart = "${pkgs.reframe}/bin/reframe-session --socket-dir=/run/reframe-session";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ sessionTarget ];
    };
  };
}
