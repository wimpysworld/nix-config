{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  name = builtins.baseNameOf (builtins.toString ./.);
  waylandCompositors = (import ../../../../lib/wayland-compositors.nix).compositors;
  desktopName = if builtins.isString host.desktop then host.desktop else "";
  compositor = lib.attrByPath [ desktopName ] null waylandCompositors;
  warpApplication = import ../lan-mouse-warp/warp-application.nix pkgs;
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    # systemd provides journalctl for the return follower, and the warp
    # application performs the local warp on a return crossing.
    runtimeInputs = [
      warpApplication
    ]
    ++ (with pkgs; [
      coreutils
      jq
      openssh
      socat
      systemd
    ]);
    text = builtins.readFile ./${name}.sh;
  };
in
lib.mkIf (noughtyLib.isUser [ "martin" ] && host.is.workstation && host.is.linux) {
  home.packages = [ shellApplication ];

  # The applier follows the lan-mouse unit: attached to the compositor
  # session target and started after the daemon it configures.
  systemd.user.services.${name} = lib.mkIf (compositor != null) {
    Unit = {
      Description = "Apply lan-mouse enter hooks";
      After = [ "lan-mouse.service" ];
      PartOf = [ compositor.sessionTarget ];
    };
    Service = {
      ExecStart = "${shellApplication}/bin/${name}";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ compositor.sessionTarget ];
  };
}
