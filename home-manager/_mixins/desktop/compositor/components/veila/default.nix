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
  resolution = d: noughtyLib.backgroundResolution "${toString d.width}x${toString d.height}";
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
    # radial scene. "file" mode overrides the catppuccin theme default. Veila
    # renders each lock surface supersampled (logical size times ceil(scale)),
    # so "center" under-fills any output with scale > 1; "fill" scales the
    # resolution-matched image to cover the buffer while preserving aspect,
    # and an image whose aspect matches exactly gets no crop. The global path
    # is the fallback for any output without an explicit block below.
    mode = "file"
    scaling = "fill"
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

    [visuals.keyboard]
    # Hide the xkb layout badge; single-layout systems gain nothing from it.
    enabled = false

    # Veila's config merge replaces arrays wholesale, so defining any
    # [[visuals.backdrop]] here discards the theme's entire backdrop array.
    # The full array from the bundled catppuccin theme is therefore carried
    # below, with these changes: the keyboard backdrop is dropped (the widget
    # is disabled above) and the columns are rearranged for symmetry around
    # the auth box. The left column (OS logo, weather icon, weather
    # temperature at y = -275/-150/-25) mirrors the right column (poweroff,
    # reboot, suspend at the same offsets), raised 50 px from the theme so the
    # poweroff box top (100 px box, y offset, valign centre) lines up with the
    # auth box top (650 px box, y = 0). Battery sits below suspend on the
    # right at y = 100 and only appears on hosts with a battery. Review these
    # blocks against assets/themes/catppuccin.toml on veila version bumps.

    # Auth
    [[visuals.backdrop]]
    enabled = true
    name = "auth"
    mode = "solid"
    color = "rgba(24, 24, 37, 1.0)"
    radius = 20
    width = 420
    height = 650
    halign = "center"
    valign = "center"
    x = 0
    y = 0
    z = 0

    # Battery
    [[visuals.backdrop]]
    name = "battery"
    show_when = "battery"
    mode = "solid"
    enabled = true
    color = "rgba(24, 24, 37, 1.0)"
    radius = 20
    width = 100
    height = 100
    halign = "center"
    valign = "center"
    y = 100
    x = 290
    z = 0

    # Poweroff
    [[visuals.backdrop]]
    enabled = true
    name = "poweroff"
    mode = "solid"
    color = "rgba(24, 24, 37, 1.0)"
    radius = 20
    width = 100
    height = 100
    halign = "center"
    valign = "center"
    y = -275
    x = 290
    z = 0

    # Reboot
    [[visuals.backdrop]]
    enabled = true
    name = "reboot"
    mode = "solid"
    color = "rgba(24, 24, 37, 1.0)"
    radius = 20
    width = 100
    height = 100
    halign = "center"
    valign = "center"
    y = -150
    x = 290
    z = 0

    # Suspend
    [[visuals.backdrop]]
    enabled = true
    name = "suspend"
    mode = "solid"
    color = "rgba(24, 24, 37, 1.0)"
    radius = 20
    width = 100
    height = 100
    halign = "center"
    valign = "center"
    y = -25
    x = 290
    z = 0

    # Weather Icon
    [[visuals.backdrop]]
    name = "weather_icon"
    show_when = "weather"
    mode = "solid"
    enabled = true
    color = "rgba(24, 24, 37, 1.0)"
    radius = 20
    width = 100
    height = 100
    halign = "center"
    valign = "center"
    y = -150
    x = -290
    z = 0

    # Weather Temperature
    [[visuals.backdrop]]
    name = "weather_temperature"
    show_when = "weather"
    mode = "solid"
    enabled = true
    color = "rgba(24, 24, 37, 1.0)"
    radius = 20
    width = 100
    height = 100
    halign = "center"
    valign = "center"
    y = -25
    x = -290
    z = 0

    # Now Playing Artwork
    [[visuals.backdrop]]
    name = "now_playing_artwork"
    show_when = "now_playing"
    mode = "solid"
    enabled = true
    color = "rgba(24, 24, 37, 1.0)"
    radius = 20
    width = 200
    height = 200
    halign = "center"
    valign = "center"
    y = 225
    x = -340
    z = 0

    # Now Playing Artist/Title
    [[visuals.backdrop]]
    name = "now_playing_artist_title"
    show_when = "now_playing"
    mode = "solid"
    enabled = true
    color = "rgba(24, 24, 37, 1.0)"
    radius = 20
    width = 650
    height = 100
    halign = "center"
    valign = "center"
    y = 405
    x = -115
    z = 0
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
