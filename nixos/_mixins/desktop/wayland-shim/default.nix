{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  desktops = {
    hyprland = {
      comment = "An intelligent dynamic tiling Wayland compositor";
      desktopNames = "Hyprland";
      launcher = "/run/current-system/sw/bin/start-hyprland";
      launcherPrefixArgs = [ "--" ];
      logName = "hyprland";
      name = "Hyprland";
      nativeSessions = config.programs.hyprland.package.providedSessions;
    };
    wayfire = {
      comment = "A modular and extensible Wayland compositor";
      desktopNames = "Wayfire";
      launcher = "/run/current-system/sw/bin/wayfire";
      launcherPrefixArgs = [ ];
      logName = "wayfire";
      name = "Wayfire";
      nativeSessions = config.programs.wayfire.package.providedSessions;
    };
  };
  supportedDesktop = builtins.isString host.desktop && builtins.hasAttr host.desktop desktops;
  desktop = desktops.${host.desktop};
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
  services.displayManager.sessionPackages = [ waylandShim ];
}
