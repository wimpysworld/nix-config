{
  catppuccinPalette,
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
  palette = catppuccinPalette;
  veila = inputs.veila.packages.${pkgs.stdenv.hostPlatform.system}.default;
  veilaBin = lib.getExe' veila "veila";
  veiladBin = lib.getExe' veila "veilad";
  fprintdEnabled = noughtyLib.hostHasTag "fprintd";
  # Match the old hyprlock placeholder glyph: a fingerprint on fprintd hosts,
  # otherwise a key.
  unlockGlyph = if fprintdEnabled then "󰈷" else "󰌋";
  # Veila detects the avatar image format from the file extension; the ~/.face
  # symlink has none ("image format could not be determined"), so point Veila at
  # the avatar's source store path, which ends in .png. Fall back to ~/.face for
  # users without a configured avatar.
  avatarImagePath =
    if config.home.file ? ".face" then
      "${config.home.file.".face".source}"
    else
      "${config.home.homeDirectory}/.face";
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
  veilaConfig = ''
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

    [fingerprint]
    # Native fprintd over D-Bus; only on hosts with the fprintd tag.
    enabled = ${lib.boolToString fprintdEnabled}

    [now_playing]
    # Show only Sidra's MPRIS player.
    include_players = ["sidra"]

    [battery]
    # The theme hardcodes battery on; gate it to laptops so desktops hide it.
    enabled = ${lib.boolToString host.is.laptop}
    refresh_seconds = 30

    [weather]
    # Open-Meteo (keyless). Basingstoke. With explicit coordinates, geocoding is
    # skipped and `location` is just the displayed place label. Temperature unit is
    # Celsius (matches the daemon's request).
    enabled = true
    location = "Basingstoke"
    latitude = 51.2667
    longitude = -1.0876
    refresh_minutes = 15
    unit = "celsius"

    [visuals.outputs]
    # UI on one output; others get secure curtains (global default is "all").
    ui_mode = "single"
    # Pin the prompt to the primary output; falls back to focused if unset.
    ui_output = "${display.primaryOutput}"

    [visuals.clock]
    # Monospace so the time doesn't shift width as the minutes tick over.
    font_family = "FiraCode Nerd Font Mono"
    format = "24h"

    [visuals.date]
    # Veila's date format is a fixed enum (long/short/iso/mdy-slash/dmy-slash),
    # not a custom strftime, so "short" is the closest preset to hyprlock's
    # "%a, %d %b".
    format = "short"
    font_family = "Work Sans"

    [visuals.now_playing.artist]
    # Work Sans for the MPRIS now-playing text, overriding the theme font.
    font_family = "Work Sans"

    [visuals.now_playing.title]
    font_family = "Work Sans"

    [visuals.input]
    # Stylised entry like the old hyprlock: a centred unlock glyph when empty
    # and centred mask symbols while typing, no "Password" label. Position and
    # size are inherited from the theme; only the styling changes here.
    placeholder = "${unlockGlyph}"
    font_family = "FiraCode Nerd Font Mono"
    font_size = 30
    mask_color = "${palette.getColor "text"}"
    background_color = "${palette.mkRgba "surface2" "1.0"}"
    border_color = "${palette.getColor "blue"}"
    border_width = 2
    radius = 8

    [visuals.placeholder]
    # Colour the unlock glyph yellow, as hyprlock did.
    color = "${palette.getColor "yellow"}"

    [visuals.avatar]
    # Render the avatar via the documented visual key. Points at the source
    # store path (ends in .png) so Veila's extension-based format detection
    # works; ~/.face has no extension and fails to load.
    enabled = true
    image_path = "${avatarImagePath}"

    [visuals.battery]
    # The theme sets colour and size; only override visibility for non-laptops.
    enabled = ${lib.boolToString host.is.laptop}

    [visuals.weather.icon]
    # The theme leaves the weather widgets off; enable the icon and temperature
    # so they render. Veila only fetches Open-Meteo when a weather widget is
    # shown, so enabling these is also what starts the weather refresh.
    enabled = true

    [visuals.weather.temperature]
    enabled = true

    [visuals.weather.location]
    enabled = true

    [visuals.eye]
    # Disable the show-password reveal toggle: the only UI path to reveal the
    # typed password.
    enabled = false

    [visuals.caps_lock]
    # Show the Caps Lock indicator when active; the theme already sets its
    # colour, so only visibility is needed.
    enabled = true
  '';
in
lib.mkIf (host.is.linux && host.is.workstation) {
  # Veila is a Wayland-native screen locker that replaces hyprlock. The package
  # and the `veila` PAM service are provided by the NixOS module; this mixin
  # writes the user config, runs the daemon and idle monitor, and binds locking.
  xdg.configFile."veila/config.toml".text = veilaConfig;

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
        # Hash the config so the unit file changes when config.toml changes,
        # making sd-switch restart veilad on `home-manager switch`.
        X-Restart-Triggers = [ (builtins.hashString "sha256" veilaConfig) ];
      };
      Service = {
        Type = "simple";
        Environment = [
          "HOME=${config.home.homeDirectory}"
          "XDG_CACHE_HOME=${config.home.homeDirectory}/.cache"
        ];
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
