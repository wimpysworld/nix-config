{
  lib,
  pkgs,
  desktop,
}:
let
  launcherArguments = [
    desktop.launcher
    desktop.name
    desktop.logName
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
    launcher
    desktopEntry
  ];
  passthru.providedSessions = [ "wayland-shim" ];
}
