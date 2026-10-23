{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  cfg = config.wayland.windowManager.mango;
  contract = (import ../../../../../lib/wayland-compositors.nix).compositors.mango;
  compositorQuery = import ../../../scripts/lan-mouse-warp/compositor-query.nix { inherit pkgs; };

  xwaylandDpi = pkgs.writeShellApplication {
    name = "xwayland-dpi";
    runtimeInputs = [
      cfg.package
      compositorQuery
    ]
    ++ (with pkgs; [
      jq
      xrdb
    ]);
    text = ''
      primary=${lib.escapeShellArg host.display.primaryOutput}
    ''
    + lib.removePrefix "#!/usr/bin/env bash\n" (builtins.readFile ./xwayland-dpi.sh);
  };
in
# Xwayland runs persistently under Mango and DISPLAY reaches the user manager
# before mango-session.target starts, so the service can set Xft.dpi at once.
lib.mkIf (host.desktop == "mango" && host.display.primaryOutput != "") {
  systemd.user.services.xwayland-dpi = {
    Unit = {
      Description = "Xft.dpi from the scale of the primary output";
      After = [ contract.sessionTarget ];
      PartOf = [ contract.sessionTarget ];
    };
    Service = {
      ExecStart = lib.getExe xwaylandDpi;
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ contract.sessionTarget ];
  };
}
