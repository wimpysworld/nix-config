{ pkgs }:
let
  fakeCommand =
    name:
    pkgs.writeShellApplication {
      inherit name;
      text = ''
        set -- ${pkgs.lib.escapeShellArg name} "$@"
      ''
      + pkgs.lib.removePrefix "#!/usr/bin/env bash\n" (
        builtins.readFile ./wayland-session-fake-command.sh
      );
    };
  fakeCommands = pkgs.symlinkJoin {
    name = "wayland-session-fake-commands";
    paths = map fakeCommand [
      "bluetoothctl"
      "dbus-update-activation-environment"
      "fake-launcher"
      "hostname"
      "playerctl"
      "systemctl"
      "unbuffer"
      "wayland-session-adapter"
      "wayland-session-cleanup"
    ];
  };
  runtimePath = pkgs.lib.makeBinPath [
    pkgs.bash
    pkgs.coreutils
    pkgs.diffutils
    pkgs.gnugrep
  ];
in
pkgs.runCommand "wayland-session-lifecycle" { } ''
  exec ${pkgs.lib.getExe pkgs.bash} ${./wayland-session-lifecycle.sh} \
    ${../../nixos/_mixins/desktop/wayland-shim/wayland-session-cleanup.sh} \
    ${../../nixos/_mixins/desktop/wayland-shim/start-wayland.sh} \
    ${../../home-manager/_mixins/scripts/wayland-session/wayland-session.sh} \
    ${fakeCommands} \
    ${pkgs.lib.escapeShellArg runtimePath}
''
