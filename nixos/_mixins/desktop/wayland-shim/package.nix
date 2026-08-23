{
  lib,
  pkgs,
  desktop,
}:
let
  cleanupArguments = [
    desktop.sessionTarget
    desktop.portalService
    (toString (builtins.length desktop.ephemeralEnvironment))
  ]
  ++ desktop.ephemeralEnvironment;
  cleanup = pkgs.writeShellApplication {
    name = "wayland-session-cleanup";
    runtimeInputs = with pkgs; [
      dbus
      systemd
    ];
    text = ''
      exec ${lib.getExe pkgs.bash} ${./wayland-session-cleanup.sh} ${lib.escapeShellArgs cleanupArguments} "$@"
    '';
  };
  launcherArguments = [
    desktop.launcher
    desktop.name
    desktop.logName
    (lib.getExe cleanup)
    (toString (builtins.length desktop.launcherPrefixArgs))
  ]
  ++ desktop.launcherPrefixArgs;
  launcher = pkgs.writeShellApplication {
    name = "start-wayland";
    runtimeInputs = with pkgs; [
      coreutils
      expect
    ];
    text = ''
      exec ${lib.getExe pkgs.bash} ${./start-wayland.sh} ${lib.escapeShellArgs launcherArguments} "$@"
    '';
  };
  desktopEntry = pkgs.writeTextFile {
    name = "wayland-shim-desktop";
    destination = "/share/wayland-sessions/wayland-shim.desktop";
    text =
      lib.replaceStrings
        [
          "@name@"
          "@comment@"
          "@desktopNames@"
        ]
        [
          desktop.name
          desktop.comment
          desktop.desktopNames
        ]
        (builtins.readFile ./wayland-shim.desktop);
  };
in
pkgs.symlinkJoin {
  name = "wayland-shim";
  paths = [
    cleanup
    launcher
    desktopEntry
  ];
  passthru.providedSessions = [ "wayland-shim" ];
}
