{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  name = builtins.baseNameOf (builtins.toString ./.);
  waylandCompositors = (import ../../../../lib/wayland-compositors.nix).compositors;
  desktopName = if builtins.isString host.desktop then host.desktop else "";
  compositor = lib.attrByPath [ desktopName ] null waylandCompositors;
  lifecycleArguments =
    if compositor == null then
      [
        ""
        "0"
      ]
    else
      [
        compositor.sessionTarget
        (toString (builtins.length compositor.startupEnvironment))
      ]
      ++ compositor.startupEnvironment;
  veila = inputs.veila.packages.${pkgs.stdenv.hostPlatform.system}.default;
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = [
      veila
    ]
    ++ (with pkgs; [
      bluez
      coreutils
      dbus
      inetutils
      playerctl
      procps
      systemd
    ]);
    text = ''
      set -- ${lib.escapeShellArgs lifecycleArguments} "$@"
    ''
    + lib.removePrefix "#!/usr/bin/env bash\n" (builtins.readFile ./wayland-session.sh);
  };
in
lib.mkIf (host.is.linux && host.is.workstation) {
  home.packages = [ shellApplication ];

  systemd.user.services.wayland-session-logout = {
    Unit.Description = "Log out of the active Wayland session";
    Service = {
      Type = "oneshot";
      ExecStart = "${shellApplication}/bin/wayland-session logout-action";
    };
  };
}
