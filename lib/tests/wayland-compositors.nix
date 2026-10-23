# The checks.x86_64-linux.wayland-compositors gate runs these assertions and script checks.
{
  lib,
  pkgs,
  enableHostIntegration ? false,
  nixosConfigurations ? { },
  homeConfigurations ? { },
}:
let
  contract = import ../wayland-compositors.nix;
  requiredPaths = [
    [
      "launcher"
      "name"
    ]
    [
      "launcher"
      "comment"
    ]
    [
      "launcher"
      "desktopNames"
    ]
    [
      "launcher"
      "command"
    ]
    [
      "launcher"
      "prefixArgs"
    ]
    [
      "launcher"
      "logName"
    ]
    [
      "launcher"
      "nativeSessions"
    ]
    [ "sessionTarget" ]
    [ "compositorStartsSessionTarget" ]
    [ "startupEnvironment" ]
    [ "ephemeralEnvironment" ]
    [
      "portal"
      "backend"
    ]
    [
      "portal"
      "packageAttr"
    ]
    [
      "portal"
      "service"
    ]
    [
      "capabilities"
      "clientSideDecorations"
    ]
    [
      "capabilities"
      "picker"
    ]
    [
      "capabilities"
      "opaqueLayers"
    ]
    [
      "waybar"
      "workspaceModule"
    ]
    [
      "waybar"
      "workspaceSettings"
    ]
  ];
  hasAttrPath =
    path: value:
    path == [ ]
    || (
      builtins.isAttrs value
      && builtins.hasAttr (builtins.head path) value
      && hasAttrPath (builtins.tail path) value.${builtins.head path}
    );
  entriesHaveRequiredFields = builtins.all (
    entry: builtins.all (path: hasAttrPath path entry) requiredPaths
  ) (builtins.attrValues contract.compositors);
  isPureData =
    value:
    if builtins.isAttrs value then
      !(value ? type && value.type == "derivation") && builtins.all isPureData (builtins.attrValues value)
    else if builtins.isList value then
      builtins.all isPureData value
    else
      builtins.elem (builtins.typeOf value) [
        "bool"
        "float"
        "int"
        "null"
        "string"
      ];

  sharedStartupEnvironment = [
    "DISPLAY"
    "WAYLAND_DISPLAY"
    "XDG_SESSION_TYPE"
    "XDG_CURRENT_DESKTOP"
    "NIXOS_OZONE_WL"
    "XCURSOR_THEME"
    "XCURSOR_SIZE"
  ];
  mangoStartupEnvironment = sharedStartupEnvironment ++ [ "MANGO_INSTANCE_SIGNATURE" ];
  mangoEphemeralEnvironment = [
    "DISPLAY"
    "MANGO_INSTANCE_SIGNATURE"
    "WAYLAND_DISPLAY"
    "XDG_SESSION_TYPE"
    "XDG_CURRENT_DESKTOP"
  ];
  wayfireStartupEnvironment = sharedStartupEnvironment ++ [ "WAYFIRE_SOCKET" ];
  wayfireEphemeralEnvironment = [
    "DISPLAY"
    "WAYFIRE_SOCKET"
    "WAYLAND_DISPLAY"
    "XDG_SESSION_TYPE"
    "XDG_CURRENT_DESKTOP"
  ];

  requiredHostConfigurationsExist =
    nixosConfigurations ? bane
    && nixosConfigurations ? felkor
    && nixosConfigurations ? skrye
    && homeConfigurations ? "martin@bane"
    && homeConfigurations ? "martin@felkor"
    && homeConfigurations ? "martin@skrye";
  baneHome = homeConfigurations."martin@bane".config;
  felkorHome = homeConfigurations."martin@felkor".config;
  skryeHome = homeConfigurations."martin@skrye".config;
  packageNamed =
    name: packages:
    let
      matches = builtins.filter (package: lib.getName package == name) packages;
    in
    assert builtins.length matches == 1;
    builtins.head matches;
  baneHomeWayfire = baneHome.wayland.windowManager.wayfire;
  baneHomeVecdecor = packageNamed "vecdecor" baneHomeWayfire.plugins;
  baneHomeExtraPlugins = packageNamed "wayfire-plugins-extra" baneHomeWayfire.plugins;
  coreHasPlugin =
    wayfire: plugin: builtins.elem plugin (lib.splitString " " wayfire.settings.core.plugins);
  vecdecorSettings = wayfire: wayfire.settings.vecdecor or { };
  expectedVecdecorSettings = {
    bg_color = "0.117647 0.117647 0.180392 1.000000";
    bg_text_color = "0.527451 0.531373 0.570588 1.0";
    border_size = 2;
    button_close_svg = "";
    button_color = "0.803922 0.839216 0.956863 1.000000";
    button_hover_color = "0.192157 0.196078 0.266667 1.000000";
    button_inactive_color = "0.529412 0.533333 0.572549 1.0";
    button_line_thickness = 1.0;
    button_maximize_svg = "";
    button_minimize_svg = "";
    button_pressed_color = "0.270588 0.278431 0.352941 1.000000";
    button_restore_svg = "";
    fg_color = "0.094118 0.094118 0.145098 1.000000";
    fg_text_color = "0.803922 0.839216 0.956863 1.000000";
    left_button_spacing = 16;
    left_button_x_offset = 0;
    right_button_spacing = 16;
    right_button_x_offset = -8;
    rounded_corner_radius = 10;
    title_font = "Work Sans Bold 13";
    title_height = 46;
    titlebar = true;
  };
  matchesVecdecorSettings =
    wayfire:
    lib.getAttrs (builtins.attrNames expectedVecdecorSettings) (vecdecorSettings wayfire)
    == expectedVecdecorSettings;
  hasGeneratedPngStatePath =
    wayfire: lib.hasInfix ".png" (builtins.toJSON (vecdecorSettings wayfire));
  expectedWinshadowsSettings = {
    clip_shadow_inside = false;
    enabled_views = ''type is "toplevel" & floating is true'';
    glow_color = "0.0 0.0 0.0 1.0";
    glow_emissivity = 0.0;
    glow_enabled = true;
    glow_intensity = 0.45;
    glow_radius_limit = 35;
    glow_spread = 5.0;
    glow_threshold = 0.09;
    horizontal_offset = 0;
    include_undecorated_views = false;
    light_type = "gaussian";
    overscale = 0.0;
    shadow_color = "0.0 0.0 0.0 0.0";
    shadow_radius = 1;
    vertical_offset = 0;
  };
  sessionPackage = home: packageNamed "wayland-session" home.home.packages;
  logoutService = home: home.systemd.user.services.wayland-session-logout;
  waylandShim = nixos: builtins.head nixos.config.services.displayManager.sessionPackages;

  wayfireCleanupArguments = lib.escapeShellArgs (
    [
      "wayfire-session.target"
      "xdg-desktop-portal-wlr"
      "5"
    ]
    ++ wayfireEphemeralEnvironment
  );
  mangoCleanupArguments = lib.escapeShellArgs (
    [
      "mango-session.target"
      "xdg-desktop-portal-wlr"
      "5"
    ]
    ++ mangoEphemeralEnvironment
  );
  mangoStartupArguments = lib.escapeShellArgs (
    [
      "mango-session.target"
      "compositor"
      "8"
    ]
    ++ mangoStartupEnvironment
  );
  wayfireStartupArguments = lib.escapeShellArgs (
    [
      "wayfire-session.target"
      "session"
      "8"
    ]
    ++ wayfireStartupEnvironment
  );

  # Home Manager issue 7124: the Home Manager portal directory hides every
  # backend that only NixOS installs, so Home Manager must list them all.
  portalNames = packages: map lib.getName packages;
  homeCoversNixosPortals =
    host:
    lib.all (
      name:
      builtins.elem name (portalNames homeConfigurations."martin@${host}".config.xdg.portal.extraPortals)
    ) (portalNames nixosConfigurations.${host}.config.xdg.portal.extraPortals);
  # Only hosts without NixOS register the portals with the user manager.
  skryeGenericHome =
    (homeConfigurations."martin@skrye".extendModules {
      modules = [ { targets.genericLinux.enable = true; } ];
    }).config;
  registersPortals =
    home:
    builtins.elem "xdg-desktop-portal" (portalNames home.systemd.user.packages)
    && builtins.elem "xdg-desktop-portal" (portalNames home.dbus.packages)
    && home.xdg.dataFile ? "xdg-desktop-portal/portals/wlr.portal"
    && home.xdg.dataFile ? "xdg-desktop-portal/portals/gtk.portal";

  # The shim must start the compositor by bare name, so that the login PATH
  # resolves the Home Manager binary.
  mangoLauncherArguments = lib.escapeShellArgs [
    "mango"
    "Mango"
    "mango"
  ];
  wayfireLauncherArguments = lib.escapeShellArgs [
    "wayfire"
    "Wayfire"
    "wayfire"
  ];

  contractResult = {
    compositorNames = builtins.attrNames contract.compositors;
    inherit (contract) default;
    pureData = isPureData contract;
    requiredFields = entriesHaveRequiredFields;
  };
in
assert
  builtins.attrNames contract.compositors == [
    "mango"
    "wayfire"
  ];
assert entriesHaveRequiredFields;
assert isPureData contract;
assert contract.default == "mango";
assert contract.compositors.mango.sessionTarget == "mango-session.target";
assert contract.compositors.mango.compositorStartsSessionTarget;
assert contract.compositors.mango.startupEnvironment == mangoStartupEnvironment;
assert contract.compositors.mango.ephemeralEnvironment == mangoEphemeralEnvironment;
assert contract.compositors.mango.portal.service == "xdg-desktop-portal-wlr";
assert contract.compositors.mango.waybar.workspaceModule == "group/workspaces";
assert
  map (n: "custom/tag${n}") (builtins.attrNames contract.compositors.mango.waybar.tagIcons)
  == contract.compositors.mango.waybar.workspaceSettings.modules;
assert !contract.compositors.mango.capabilities.clientSideDecorations;
assert contract.compositors.mango.capabilities.opaqueLayers;
assert contract.compositors.wayfire.sessionTarget == "wayfire-session.target";
assert !contract.compositors.wayfire.compositorStartsSessionTarget;
assert contract.compositors.wayfire.startupEnvironment == wayfireStartupEnvironment;
assert contract.compositors.wayfire.ephemeralEnvironment == wayfireEphemeralEnvironment;
assert contract.compositors.wayfire.portal.service == "xdg-desktop-portal-wlr";
assert !(contract.compositors.wayfire.waybar.workspaceSettings ? on-click);
assert !(contract.compositors.wayfire.waybar.workspaceSettings ? sort-by-number);
assert !enableHostIntegration || requiredHostConfigurationsExist;
assert
  !enableHostIntegration
  || baneHome.wayland.windowManager.wayfire.systemd.variables == wayfireStartupEnvironment;
assert !enableHostIntegration || baneHome.wayland.systemd.target == "wayfire-session.target";
assert !enableHostIntegration || skryeHome.wayland.systemd.target == "mango-session.target";
assert !enableHostIntegration || skryeHome.wayland.windowManager.mango.enable;
assert !enableHostIntegration || !nixosConfigurations.skrye.config.programs.mangowc.enable;
assert
  !enableHostIntegration
  || builtins.elem skryeHome.wayland.windowManager.mango.package skryeHome.home.packages;
assert !enableHostIntegration || felkorHome.wayland.systemd.target == "mango-session.target";
# The package unit must stay in charge, so Home Manager adds only a drop-in.
assert !enableHostIntegration || !(felkorHome.systemd.user.targets ? mango-session);
assert
  !enableHostIntegration
  ||
    lib.hasInfix "Wants=xdg-desktop-autostart.target"
      felkorHome.xdg.configFile."systemd/user/mango-session.target.d/autostart.conf".text;
assert !enableHostIntegration || !nixosConfigurations.felkor.config.programs.mangowc.enable;
assert
  !enableHostIntegration
  || lib.versions.majorMinor felkorHome.wayland.windowManager.mango.package.version == "0.18";
assert !enableHostIntegration || !nixosConfigurations.bane.config.programs.wayfire.enable;
assert
  !enableHostIntegration || lib.getName baneHomeWayfire.package == "wayfire-with-gsettings-schemas";
assert !enableHostIntegration || lib.getName baneHomeVecdecor == "vecdecor";
assert !enableHostIntegration || homeCoversNixosPortals "bane";
assert !enableHostIntegration || homeCoversNixosPortals "skrye";
assert !enableHostIntegration || !(registersPortals skryeHome);
assert !enableHostIntegration || registersPortals skryeGenericHome;
assert
  !enableHostIntegration || builtins.elem "-Denable_pixdecor=true" baneHomeExtraPlugins.mesonFlags;
assert !enableHostIntegration || coreHasPlugin baneHomeWayfire "vecdecor";
assert !enableHostIntegration || !(coreHasPlugin baneHomeWayfire "pixdecor");
assert !enableHostIntegration || baneHomeWayfire.settings ? vecdecor;
assert !enableHostIntegration || !(baneHomeWayfire.settings ? pixdecor);
assert !enableHostIntegration || matchesVecdecorSettings baneHomeWayfire;
assert !enableHostIntegration || !(hasGeneratedPngStatePath baneHomeWayfire);
assert !enableHostIntegration || baneHomeWayfire.settings.winshadows == expectedWinshadowsSettings;
assert
  !enableHostIntegration
  || felkorHome.systemd.user.services.lan-mouse.Unit.PartOf == [ "mango-session.target" ];
assert
  !enableHostIntegration
  || felkorHome.systemd.user.services.lan-mouse.Install.WantedBy == [ "mango-session.target" ];
assert
  !enableHostIntegration
  || skryeHome.systemd.user.services.reframe-session.Unit.PartOf == [ "mango-session.target" ];
assert
  !enableHostIntegration
  || skryeHome.systemd.user.services.reframe-session.Install.WantedBy == [ "mango-session.target" ];
assert
  !enableHostIntegration
  ||
    (logoutService baneHome).Service.ExecStart == [
      "${sessionPackage baneHome}/bin/wayland-session logout-action"
    ];
assert !enableHostIntegration || (logoutService baneHome).Service.Type == "oneshot";
assert !enableHostIntegration || !((logoutService baneHome).Unit ? PartOf);
assert !enableHostIntegration || !(logoutService baneHome ? Install);
assert
  !enableHostIntegration
  ||
    (logoutService skryeHome).Service.ExecStart == [
      "${sessionPackage skryeHome}/bin/wayland-session logout-action"
    ];
assert !enableHostIntegration || (logoutService skryeHome).Service.Type == "oneshot";
assert !enableHostIntegration || !((logoutService skryeHome).Unit ? PartOf);
assert !enableHostIntegration || !(logoutService skryeHome ? Install);
assert
  !enableHostIntegration
  ||
    (logoutService felkorHome).Service.ExecStart == [
      "${sessionPackage felkorHome}/bin/wayland-session logout-action"
    ];
assert !enableHostIntegration || (logoutService felkorHome).Service.Type == "oneshot";
assert !enableHostIntegration || !((logoutService felkorHome).Unit ? PartOf);
assert !enableHostIntegration || !(logoutService felkorHome ? Install);
pkgs.runCommand "wayland-compositor-contract" { } ''
  ${lib.optionalString enableHostIntegration ''
    grep -F -- ${lib.escapeShellArg wayfireCleanupArguments} \
      ${waylandShim nixosConfigurations.bane}/bin/wayland-session-cleanup >/dev/null
    grep -F -- ${lib.escapeShellArg mangoCleanupArguments} \
      ${waylandShim nixosConfigurations.felkor}/bin/wayland-session-cleanup >/dev/null
    grep -F -- ${lib.escapeShellArg mangoCleanupArguments} \
      ${waylandShim nixosConfigurations.skrye}/bin/wayland-session-cleanup >/dev/null
    grep -F -- ${lib.escapeShellArg "start-wayland.sh ${wayfireLauncherArguments} "} \
      ${waylandShim nixosConfigurations.bane}/bin/start-wayland >/dev/null
    grep -F -- ${lib.escapeShellArg "start-wayland.sh ${mangoLauncherArguments} "} \
      ${waylandShim nixosConfigurations.skrye}/bin/start-wayland >/dev/null
    grep -F -- ${lib.escapeShellArg "set -- ${wayfireStartupArguments} \"\$@\""} \
      ${sessionPackage baneHome}/bin/wayland-session >/dev/null
    grep -F -- ${lib.escapeShellArg "set -- ${mangoStartupArguments} \"\$@\""} \
      ${sessionPackage felkorHome}/bin/wayland-session >/dev/null
    grep -F -- ${lib.escapeShellArg "set -- ${mangoStartupArguments} \"\$@\""} \
      ${sessionPackage skryeHome}/bin/wayland-session >/dev/null
  ''}
  printf '%s\n' ${lib.escapeShellArg (builtins.toJSON contractResult)} > "$out"
''
