{
  config,
  inputs,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  inherit (host) display displays;
  veila = inputs.veila.packages.${pkgs.stdenv.hostPlatform.system}.default;
  veilaBin = lib.getExe' veila "veila";
  veiladBin = lib.getExe' veila "veilad";
  fprintdEnabled = noughtyLib.hostHasTag "fprintd";
  passEnvironment = "WAYLAND_DISPLAY XDG_SESSION_ID XDG_SESSION_TYPE XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE SWAYSOCK NIRI_SOCKET";
  # Mirror the wpaperd per-display mapping exactly: index 0 is the primary and
  # gets a Catppuccin wallpaper; subsequent displays get Colorway. Resolution and
  # output name come from the same noughty display fields wpaperd reads.
  resolution = d: "${toString d.width}x${toString d.height}";
  wallpaperVariant = i: if i == 0 then "Catppuccin" else "Colorway";
  wallpaperPath = i: d: "/etc/backgrounds/${wallpaperVariant i}-${resolution d}.png";
  # Global fallback: the primary display's Catppuccin wallpaper, or the 1080p
  # Catppuccin default when no displays are registered (wpaperd's "any" branch).
  fallbackPath =
    if displays != [ ] then
      wallpaperPath 0 (builtins.head displays)
    else
      "/etc/backgrounds/Catppuccin-1920x1080.png";
  # One [[background.outputs]] block per display, separated by blank lines.
  backgroundOutputs = lib.concatStringsSep "\n" (
    lib.imap0 (i: d: ''
      [[background.outputs]]
      name = "${d.output}"
      path = "${wallpaperPath i d}"
    '') displays
  );
in
lib.mkIf (host.is.linux && host.is.workstation) {
  # Veila is a Wayland-native screen locker that replaces hyprlock. The package
  # and the `veila` PAM service are provided by the NixOS module; this mixin
  # writes the user config, runs the daemon and idle monitor, and binds locking.
  xdg.configFile."veila/config.toml".text = ''
    # The bundled "catppuccin" preset is Catppuccin Mocha out of the box, so the
    # config only sets behaviour and the few personal keys; the main config
    # always wins over the theme.
    theme = "catppuccin"

    [background]
    # Use the same per-monitor wallpapers as the desktop instead of the theme's
    # radial scene. "file" mode overrides the catppuccin theme default; "center"
    # mirrors wpaperd's center mode for the resolution-matched PNGs. The global
    # path is the fallback for any output without an explicit block below.
    mode = "file"
    scaling = "center"
    path = "${fallbackPath}"

    ${backgroundOutputs}
    [lock]
    # Keep the pointer visible so the user can navigate and click while locked;
    # Hyprland supplies the cursor via the cursor-shape protocol.
    hide_cursor = false
    # Submit Enter-on-empty to PAM so the fingerprint flow can proceed.
    allow_empty_password = true
    # Power displays off while locked (replaces hypridle's dpms listener).
    screen_off_seconds = 305
    # suspend_seconds left unset: suspend stays with logind, not Veila.
    # The avatar source image is set here in [lock] (a LockConfig field), not in
    # [visuals.avatar]; Veila loads and caches it under ~/.cache/veila/avatars,
    # and the visual block below only styles size and position.
    avatar_path = "${config.home.homeDirectory}/.face"

    [fingerprint]
    # Native fprintd over D-Bus; only on hosts with the fprintd tag.
    enabled = ${lib.boolToString fprintdEnabled}

    [now_playing]
    # Show only Sidra's MPRIS player.
    include_players = ["sidra"]

    [visuals.outputs]
    # UI on one output; others get secure curtains (global default is "all").
    ui_mode = "single"
    # Pin the prompt to the primary output; falls back to focused if unset.
    ui_output = "${display.primaryOutput}"

    [visuals.clock]
    format = "24h"

    [visuals.avatar]
    # Render the avatar (source image set via [lock] avatar_path above), as the
    # old hyprlock screen did.
    enabled = true
  '';

  # Tune the packaged idle monitor without editing the unit file.
  xdg.configFile."veila/idle.env".text = ''
    VEILA_IDLE_LOCK_AFTER=300
    VEILA_IDLE_SLEEP_FLAG=--lock-before-sleep
  '';

  # Run the locker daemon and idle monitor as user services. The package ships
  # these as templates under share/veila/systemd with Debian paths, so define
  # them here against the Nix store binaries.
  systemd.user.services = {
    veilad = {
      Unit = {
        Description = "Veila screen locker daemon";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = veiladBin;
        Restart = "on-failure";
        RestartSec = 2;
        PassEnvironment = passEnvironment;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
    veila-idle = {
      Unit = {
        Description = "Veila idle and sleep lock monitor";
        After = [
          "graphical-session.target"
          "veilad.service"
        ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        Environment = [
          "VEILA_IDLE_LOCK_AFTER=300"
          "VEILA_IDLE_SLEEP_FLAG=--lock-before-sleep"
        ];
        EnvironmentFile = "-%h/.config/veila/idle.env";
        ExecStart = "${veilaBin} idle --lock-after=\${VEILA_IDLE_LOCK_AFTER} $VEILA_IDLE_SLEEP_FLAG";
        Restart = "on-failure";
        RestartSec = 2;
        PassEnvironment = passEnvironment;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };

  wayland.windowManager.hyprland = {
    settings = {
      bind = [
        "$mod, L, exec, ${veilaBin} lock"
        "CTRL ALT, L, exec, ${veilaBin} lock"
      ];
    };
  };
}
