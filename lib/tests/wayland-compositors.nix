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
      "nativeSessionsPath"
    ]
    [ "sessionTarget" ]
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
  hyprlandStartupEnvironment = sharedStartupEnvironment ++ [ "HYPRLAND_INSTANCE_SIGNATURE" ];
  hyprlandEphemeralEnvironment = [
    "DISPLAY"
    "HYPRLAND_INSTANCE_SIGNATURE"
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
  baneNixosWayfirePlugins = nixosConfigurations.bane.config.programs.wayfire.plugins;
  felkorNixosWayfirePlugins = nixosConfigurations.felkor.config.programs.wayfire.plugins;
  packageNamed =
    name: packages:
    let
      matches = builtins.filter (package: lib.getName package == name) packages;
    in
    assert builtins.length matches == 1;
    builtins.head matches;
  baneHomeWayfire = baneHome.wayland.windowManager.wayfire;
  felkorHomeWayfire = felkorHome.wayland.windowManager.wayfire;
  baneNixosVecdecor = packageNamed "vecdecor" baneNixosWayfirePlugins;
  baneHomeVecdecor = packageNamed "vecdecor" baneHomeWayfire.plugins;
  felkorNixosVecdecor = packageNamed "vecdecor" felkorNixosWayfirePlugins;
  felkorHomeVecdecor = packageNamed "vecdecor" felkorHomeWayfire.plugins;
  baneNixosExtraPlugins = packageNamed "wayfire-plugins-extra" baneNixosWayfirePlugins;
  baneHomeExtraPlugins = packageNamed "wayfire-plugins-extra" baneHomeWayfire.plugins;
  felkorNixosExtraPlugins = packageNamed "wayfire-plugins-extra" felkorNixosWayfirePlugins;
  felkorHomeExtraPlugins = packageNamed "wayfire-plugins-extra" felkorHomeWayfire.plugins;
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
    button_size = 34;
    fg_color = "0.094118 0.094118 0.145098 1.000000";
    fg_text_color = "0.803922 0.839216 0.956863 1.000000";
    left_button_spacing = 16;
    left_button_x_offset = 0;
    right_button_spacing = 16;
    right_button_x_offset = -16;
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
  waylandShim =
    host: builtins.head nixosConfigurations.${host}.config.services.displayManager.sessionPackages;

  wayfireCleanupArguments = lib.escapeShellArgs (
    [
      "wayfire-session.target"
      "xdg-desktop-portal-wlr"
      "5"
    ]
    ++ wayfireEphemeralEnvironment
  );
  hyprlandCleanupArguments = lib.escapeShellArgs (
    [
      "hyprland-session.target"
      "xdg-desktop-portal-hyprland"
      "5"
    ]
    ++ hyprlandEphemeralEnvironment
  );
  wayfireStartupArguments = lib.escapeShellArgs (
    [
      "wayfire-session.target"
      "8"
    ]
    ++ wayfireStartupEnvironment
  );
  hyprlandStartupArguments = lib.escapeShellArgs (
    [
      "hyprland-session.target"
      "8"
    ]
    ++ hyprlandStartupEnvironment
  );

  contractResult = {
    compositorNames = builtins.attrNames contract.compositors;
    inherit (contract) default;
    pureData = isPureData contract;
    requiredFields = entriesHaveRequiredFields;
  };
  cleanupSource = ../../nixos/_mixins/desktop/wayland-shim/wayland-session-cleanup.sh;
  launcherSource = ../../nixos/_mixins/desktop/wayland-shim/start-wayland.sh;
  sessionSource = ../../home-manager/_mixins/scripts/wayland-session/wayland-session.sh;
in
assert
  builtins.attrNames contract.compositors == [
    "hyprland"
    "wayfire"
  ];
assert entriesHaveRequiredFields;
assert isPureData contract;
assert contract.default == "hyprland";
assert contract.compositors.hyprland.sessionTarget == "hyprland-session.target";
assert contract.compositors.hyprland.startupEnvironment == hyprlandStartupEnvironment;
assert contract.compositors.hyprland.ephemeralEnvironment == hyprlandEphemeralEnvironment;
assert contract.compositors.hyprland.portal.service == "xdg-desktop-portal-hyprland";
assert contract.compositors.wayfire.sessionTarget == "wayfire-session.target";
assert contract.compositors.wayfire.startupEnvironment == wayfireStartupEnvironment;
assert contract.compositors.wayfire.ephemeralEnvironment == wayfireEphemeralEnvironment;
assert contract.compositors.wayfire.portal.service == "xdg-desktop-portal-wlr";
assert contract.compositors.hyprland.waybar.workspaceSettings.on-click == "activate";
assert contract.compositors.hyprland.waybar.workspaceSettings.sort-by-number;
assert !(contract.compositors.wayfire.waybar.workspaceSettings ? on-click);
assert !(contract.compositors.wayfire.waybar.workspaceSettings ? sort-by-number);
assert !enableHostIntegration || requiredHostConfigurationsExist;
assert
  !enableHostIntegration
  || baneHome.wayland.windowManager.wayfire.systemd.variables == wayfireStartupEnvironment;
assert
  !enableHostIntegration
  || felkorHome.wayland.windowManager.wayfire.systemd.variables == wayfireStartupEnvironment;
assert
  !enableHostIntegration
  || skryeHome.wayland.windowManager.hyprland.systemd.variables == hyprlandStartupEnvironment;
assert !enableHostIntegration || baneHome.wayland.systemd.target == "wayfire-session.target";
assert !enableHostIntegration || felkorHome.wayland.systemd.target == "wayfire-session.target";
assert !enableHostIntegration || skryeHome.wayland.systemd.target == "hyprland-session.target";
assert !enableHostIntegration || lib.getName felkorNixosVecdecor == "vecdecor";
assert !enableHostIntegration || lib.getName felkorHomeVecdecor == "vecdecor";
assert
  !enableHostIntegration || builtins.elem "-Denable_pixdecor=true" felkorNixosExtraPlugins.mesonFlags;
assert
  !enableHostIntegration || builtins.elem "-Denable_pixdecor=true" felkorHomeExtraPlugins.mesonFlags;
assert !enableHostIntegration || coreHasPlugin felkorHomeWayfire "vecdecor";
assert !enableHostIntegration || !(coreHasPlugin felkorHomeWayfire "pixdecor");
assert !enableHostIntegration || felkorHomeWayfire.settings ? vecdecor;
assert !enableHostIntegration || !(felkorHomeWayfire.settings ? pixdecor);
assert !enableHostIntegration || matchesVecdecorSettings felkorHomeWayfire;
assert !enableHostIntegration || !(hasGeneratedPngStatePath felkorHomeWayfire);
assert
  !enableHostIntegration || felkorHomeWayfire.settings.winshadows == expectedWinshadowsSettings;
assert !enableHostIntegration || lib.getName baneNixosVecdecor == "vecdecor";
assert !enableHostIntegration || lib.getName baneHomeVecdecor == "vecdecor";
assert
  !enableHostIntegration || builtins.elem "-Denable_pixdecor=true" baneNixosExtraPlugins.mesonFlags;
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
  || baneHome.systemd.user.services.reframe-session.Unit.PartOf == [ "wayfire-session.target" ];
assert
  !enableHostIntegration
  || baneHome.systemd.user.services.reframe-session.Install.WantedBy == [ "wayfire-session.target" ];
assert
  !enableHostIntegration
  || felkorHome.systemd.user.services.lan-mouse.Unit.PartOf == [ "wayfire-session.target" ];
assert
  !enableHostIntegration
  || felkorHome.systemd.user.services.lan-mouse.Install.WantedBy == [ "wayfire-session.target" ];
assert
  !enableHostIntegration
  || skryeHome.systemd.user.services.reframe-session.Unit.PartOf == [ "hyprland-session.target" ];
assert
  !enableHostIntegration
  ||
    skryeHome.systemd.user.services.reframe-session.Install.WantedBy == [ "hyprland-session.target" ];
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
    (logoutService felkorHome).Service.ExecStart == [
      "${sessionPackage felkorHome}/bin/wayland-session logout-action"
    ];
assert !enableHostIntegration || (logoutService felkorHome).Service.Type == "oneshot";
assert !enableHostIntegration || !((logoutService felkorHome).Unit ? PartOf);
assert !enableHostIntegration || !(logoutService felkorHome ? Install);
assert
  !enableHostIntegration
  ||
    (logoutService skryeHome).Service.ExecStart == [
      "${sessionPackage skryeHome}/bin/wayland-session logout-action"
    ];
assert !enableHostIntegration || (logoutService skryeHome).Service.Type == "oneshot";
assert !enableHostIntegration || !((logoutService skryeHome).Unit ? PartOf);
assert !enableHostIntegration || !(logoutService skryeHome ? Install);
pkgs.runCommand "wayland-compositor-contract" { } ''
  finalise_block=$(sed -n '/^finalise)/,/^recover)/p' ${cleanupSource})
  test "$finalise_block" = $'finalise)\n\tstop_session\n\tneutralise_environment\n\treset_start_limits\n\t;;\nrecover)'

  dbus_line=$(grep -nF 'dbus-update-activation-environment --systemd' ${cleanupSource} | cut -d: -f1)
  systemd_line=$(grep -nF 'systemctl --user unset-environment' ${cleanupSource} | cut -d: -f1)
  test "$dbus_line" -lt "$systemd_line"
  grep -F -- 'systemctl --user show --property=Wants --value "$session_target"' \
    ${cleanupSource} >/dev/null
  grep -F -- 'reset-failed "''${reset_units[@]}"' ${cleanupSource} >/dev/null

  prepare_line=$(grep -nF $'\tprepare_logout' ${sessionSource} | cut -d: -f1)
  adapter_line=$(grep -nF $'\twayland-session-adapter logout' ${sessionSource} | cut -d: -f1)
  test "$prepare_line" -lt "$adapter_line"
  grep -F -- $'logout)\n\tsystemctl --user start --no-block wayland-session-logout.service' \
    ${sessionSource} >/dev/null
  grep -F -- 'exit "$launcher_status"' ${launcherSource} >/dev/null

  ${lib.optionalString enableHostIntegration ''
    grep -F -- ${lib.escapeShellArg wayfireCleanupArguments} \
      ${waylandShim "bane"}/bin/wayland-session-cleanup >/dev/null
    grep -F -- ${lib.escapeShellArg wayfireCleanupArguments} \
      ${waylandShim "felkor"}/bin/wayland-session-cleanup >/dev/null
    grep -F -- ${lib.escapeShellArg hyprlandCleanupArguments} \
      ${waylandShim "skrye"}/bin/wayland-session-cleanup >/dev/null
    grep -F -- ${lib.escapeShellArg "set -- ${wayfireStartupArguments} \"\$@\""} \
      ${sessionPackage baneHome}/bin/wayland-session >/dev/null
    grep -F -- ${lib.escapeShellArg "set -- ${wayfireStartupArguments} \"\$@\""} \
      ${sessionPackage felkorHome}/bin/wayland-session >/dev/null
    grep -F -- ${lib.escapeShellArg "set -- ${hyprlandStartupArguments} \"\$@\""} \
      ${sessionPackage skryeHome}/bin/wayland-session >/dev/null

    export bane_startup_log="$TMPDIR/bane-startup.log"
    : > "$bane_startup_log"
    record_bane_event() {
      local argument
      local command_name=$1
      shift

      printf '%s' "$command_name" >> "$bane_startup_log"
      for argument in "$@"; do
        printf ' <%s>' "$argument" >> "$bane_startup_log"
      done
      printf '\n' >> "$bane_startup_log"
    }
    wayland-session-cleanup() {
      record_bane_event wayland-session-cleanup "$@"
      printf 'wayland-session-cleanup: generated Bane recovery warning\n' >&2
      return 9
    }
    dbus-update-activation-environment() {
      record_bane_event dbus-update-activation-environment "$@"
    }
    systemctl() {
      record_bane_event systemctl "$@"
    }
    hostname() {
      printf 'bane\n'
    }
    export -f record_bane_event wayland-session-cleanup
    export -f dbus-update-activation-environment systemctl hostname

    ${sessionPackage baneHome}/bin/wayland-session start 2>"$TMPDIR/bane-startup.stderr"
    printf '%s' $'wayland-session-cleanup <recover>\ndbus-update-activation-environment <--systemd> <DISPLAY> <WAYLAND_DISPLAY> <XDG_SESSION_TYPE> <XDG_CURRENT_DESKTOP> <NIXOS_OZONE_WL> <XCURSOR_THEME> <XCURSOR_SIZE> <WAYFIRE_SOCKET>\nsystemctl <--user> <start> <wayfire-session.target>\n' \
      >"$TMPDIR/bane-startup.expected"
    diff -u "$TMPDIR/bane-startup.expected" "$bane_startup_log"
    grep -Fx 'wayland-session-cleanup: generated Bane recovery warning' \
      "$TMPDIR/bane-startup.stderr" >/dev/null
    grep -Fx 'wayland-session: recovery failed with code 9, startup will continue' \
      "$TMPDIR/bane-startup.stderr" >/dev/null
  ''}
  printf '%s\n' ${lib.escapeShellArg (builtins.toJSON contractResult)} > "$out"
''
