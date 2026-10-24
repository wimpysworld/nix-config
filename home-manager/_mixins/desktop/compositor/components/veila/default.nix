{
  catppuccinPalette,
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  inherit (host) display displays;
  palette = catppuccinPalette;
  inherit (pkgs) veila;
  veilaBin = lib.getExe' veila "veila";
  veiladBin = lib.getExe' veila "veilad";
  # Seconds of idle before hypridle locks the session. The fade starts earlier
  # so that it ends at the lock.
  idleLockAfter = 300;
  fadeSeconds = 10;
  veilaFadeLock = pkgs.writeShellApplication {
    name = "veila-fade-lock";
    runtimeInputs = [
      pkgs.chayang
      veila
    ];
    text = ''
      # chayang exits 0 when the fade completes, 2 when input cancels it and 1
      # on error. Lock on 0 and 1 so that a fault never leaves the session
      # unlocked; do nothing on 2.
      status=0
      chayang -d ${toString fadeSeconds} || status=$?
      if [ "$status" -ne 2 ]; then
        veila lock
      fi
    '';
  };
  # hypridle owns the idle lock, and veila-idle only locks before sleep.
  # `veila idle` cannot disable its idle timer, so this workaround sets the
  # timer to about 23 days. The value keeps the timer in milliseconds below
  # INT_MAX, which wlroots requires. Never disable hypridle without restoring
  # this timer, or the session stops locking on idle.
  sleepGuardLockAfter = 2000000;
  fprintdEnabled = noughtyLib.hostHasTag "fprintd";
  # The placeholder glyph is a pink fingerprint on fprintd hosts, otherwise a
  # yellow key.
  unlockGlyph = if fprintdEnabled then "󰈷" else "󰌋";
  unlockGlyphColor = if fprintdEnabled then "pink" else "yellow";
  # Use the avatar's source store path. Fall back to ~/.face for users without
  # a configured avatar.
  avatarImagePath =
    if config.home.file ? ".face" then
      "${config.home.file.".face".source}"
    else
      "${config.home.homeDirectory}/.face";
  passEnvironment = "WAYLAND_DISPLAY XDG_SESSION_ID XDG_SESSION_TYPE XDG_CURRENT_DESKTOP SWAYSOCK NIRI_SOCKET MANGO_INSTANCE_SIGNATURE";
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
    # the Wayland compositor supplies the cursor via the cursor-shape protocol.
    hide_cursor = false
    # Ignore Enter on an empty password. The native fprintd loop runs without
    # a submit, and an empty submit only counts a failed PAM attempt.
    allow_empty_password = false
    # Power displays off while locked.
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
    # not a custom strftime, so "short" is the closest preset to
    # "%a, %d %b".
    format = "short"
    font_family = "Work Sans"

    [visuals.now_playing.artist]
    # Work Sans for the MPRIS now-playing text, overriding the theme font.
    font_family = "Work Sans"

    [visuals.now_playing.title]
    font_family = "Work Sans"

    [visuals.input]
    # Stylised entry: an unlock glyph when empty and mask dots while typing, no
    # "Password" label. Both start at the left padding of the box, not the
    # centre. Position and size are inherited from the theme; only the styling
    # changes here. font_size also sizes the glyph and the inline status text.
    placeholder = "${unlockGlyph}"
    font_family = "FiraCode Nerd Font Mono"
    # Bold keeps the same width in a monospaced font, so the text looks
    # stronger and "Authentication failed" still fits the 360 px box,
    # which holds it up to about 21 points.
    font_weight = 700
    font_size = 21
    mask_color = "${palette.getColor "text"}"
    # Dot diameter and centre-to-centre spacing in logical pixels, from the
    # local mask-size patch (the defaults are 7 and 16).
    mask_size = 12
    mask_spacing = 20
    background_color = "${palette.mkRgba "surface2" "1.0"}"
    border_color = "${palette.getColor "blue"}"
    border_width = 2
    radius = 8

    [visuals.placeholder]
    # Colour and size the unlock glyph, from the local placeholder-style
    # patch. Veila draws an opaque placeholder colour at about 60% alpha, so
    # opacity (a percentage) keeps the glyph opaque. A 36 px glyph has a 48 px
    # line box, which fits the 54 px input box and stays centred in it.
    color = "${palette.getColor unlockGlyphColor}"
    opacity = ${toString (builtins.floor (palette.alpha.opaque * 100 + 0.5))}
    font_size = 36

    [visuals.avatar]
    # Render the avatar via the documented visual key.
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
    # Hide the place label. The icon and temperature stay, and they keep the
    # weather refresh running.
    enabled = false

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
  compositor =
    if host.is.linux && host.is.workstation then
      lib.attrByPath [
        host.desktop
      ] null (import ../../../../../../lib/wayland-compositors.nix).compositors
    else
      null;
  sessionTarget = if compositor == null then "graphical-session.target" else compositor.sessionTarget;
in
lib.mkIf (host.is.linux && host.is.workstation) {
  # Veila is a Wayland-native screen locker. The package
  # and the `veila` PAM service are provided by the NixOS module; this mixin
  # writes the user config, runs the daemon and sleep lock monitor, and binds
  # locking.
  #
  # The lock stack has three parts that depend on each other:
  # - hypridle fades the screen after 290 seconds of idle and locks at 300.
  #   It honours org.freedesktop.ScreenSaver inhibits from applications and
  #   the Inhibit portal, Wayland idle inhibitors such as the Waybar toggle,
  #   and logind idle inhibitors. Music alone does not inhibit, so the
  #   session still locks while it plays.
  # - veila-idle only locks before sleep, and holds sleep until the lock is
  #   visible. Its own idle timer is pushed out of the way.
  # - veilad draws the lock screen, and also locks on the logind Lock signal.
  xdg.configFile."veila/config.toml".text = veilaConfig;

  services.hypridle = {
    enable = true;
    systemdTarget = sessionTarget;
    settings = {
      general = {
        # veila-idle holds sleep until the lock is visible. hypridle can only
        # do that through hyprland-lock-notify-v1, which Mango and Wayfire do
        # not provide.
        inhibit_sleep = 0;
      };
      # No on-resume, because input cancels the fade and Veila wakes the
      # outputs while locked.
      listener = [
        {
          timeout = idleLockAfter - fadeSeconds;
          on-timeout = lib.getExe veilaFadeLock;
        }
      ];
    };
  };

  # Tune the packaged sleep lock monitor without editing the unit file.
  xdg.configFile."veila/idle.env".text = ''
    VEILA_IDLE_LOCK_AFTER=${toString sleepGuardLockAfter}
    VEILA_IDLE_SLEEP_FLAG=--lock-before-sleep
  '';

  # Run the locker daemon and sleep lock monitor as user services. The package ships
  # these as templates under share/veila/systemd with Debian paths, so define
  # them here against the Nix store binaries.
  systemd.user.services = {
    veilad = {
      Unit = {
        Description = "Veila screen locker daemon";
        After = [ sessionTarget ];
        PartOf = [ sessionTarget ];
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
      Install.WantedBy = [ sessionTarget ];
    };
    veila-idle = {
      Unit = {
        Description = "Veila sleep lock monitor";
        After = [
          sessionTarget
          "veilad.service"
        ];
        PartOf = [ sessionTarget ];
      };
      Service = {
        Type = "simple";
        Environment = [
          "VEILA_IDLE_LOCK_AFTER=${toString sleepGuardLockAfter}"
          "VEILA_IDLE_SLEEP_FLAG=--lock-before-sleep"
        ];
        EnvironmentFile = "-%h/.config/veila/idle.env";
        ExecStart = "${veilaBin} idle --lock-after=\${VEILA_IDLE_LOCK_AFTER} $VEILA_IDLE_SLEEP_FLAG";
        Restart = "on-failure";
        RestartSec = 2;
        PassEnvironment = passEnvironment;
      };
      Install.WantedBy = [ sessionTarget ];
    };
  };
}
