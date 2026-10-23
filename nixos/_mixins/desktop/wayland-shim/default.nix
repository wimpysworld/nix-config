{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  waylandCompositors = (import ../../../../lib/wayland-compositors.nix).compositors;
  desktopName = if builtins.isString host.desktop then host.desktop else "";
  compositor = lib.attrByPath [ desktopName ] null waylandCompositors;
  supportedDesktop = compositor != null;
  desktop = {
    inherit (compositor.launcher)
      comment
      desktopNames
      logName
      name
      nativeSessions
      ;
    # Home Manager installs the compositor, so the launcher is a bare command
    # that resolves through the login PATH to the user profile.
    launcher = compositor.launcher.command;
    launcherPrefixArgs = compositor.launcher.prefixArgs;
    inherit (compositor) ephemeralEnvironment sessionTarget;
    portalService = compositor.portal.service;
  };
  hiddenWaylandSessions = map (
    name:
    pkgs.writeTextDir "share/wayland-sessions/${name}.desktop" ''
      [Desktop Entry]
      Name="Hidden-${name}"
      NoDisplay=true
    ''
  ) desktop.nativeSessions;
  waylandShim = pkgs.callPackage ./package.nix { inherit desktop; };
in
lib.mkIf (host.is.workstation && supportedDesktop) {
  environment = {
    sessionVariables.XDG_DATA_DIRS = map (session: "${session}/share") hiddenWaylandSessions;
    systemPackages = [ waylandShim ];
  };
  services.displayManager.sessionPackages = lib.mkForce [ waylandShim ];
}
