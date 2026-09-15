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
  cursorPackage =
    pkgs.catppuccin-cursors."${catppuccinPalette.flavor}${
      lib.toUpper (builtins.substring 0 1 catppuccinPalette.accent)
    }${builtins.substring 1 (-1) catppuccinPalette.accent}";
  gtkThemePackage = pkgs.catppuccin-gtk.override {
    accents = [ "${catppuccinPalette.accent}" ];
    variant = catppuccinPalette.flavor;
  };
  iconTheme = if catppuccinPalette.isDark then "Papirus-Dark" else "Papirus-Light";
  regreetDataDirs = lib.makeSearchPath "share" [
    config.services.displayManager.sessionData.desktops
    gtkThemePackage
    cursorPackage
    pkgs.papirus-icon-theme
  ];
  # Reference for setting display configuration for cage
  # - https://github.com/cage-kiosk/cage/issues/304
  # - https://github.com/cage-kiosk/cage/issues/257
  # GTK4 >= 4.16 on Wayland no longer loads Xcursor themes from disk; it only
  # renders cursors via wp_cursor_shape_v1 (offloaded to the compositor) or its
  # bundled GResource fallback. Cage 0.3.0 does not advertise wp_cursor_shape_v1,
  # so regreet's cursor reverts to the GTK4 default on pointer-enter. labwc does
  # advertise it, but the greeter behaviour changed enough that Cage remains the
  # preferred compositor. See https://gitlab.gnome.org/GNOME/gtk/-/blob/4.22.4/gdk/wayland/gdkcursor-wayland.c
  regreetCage = pkgs.writeShellScriptBin "regreet-cage" ''
    # Start regreet in a Wayland kiosk using Cage
    export GTK_THEME="catppuccin-${catppuccinPalette.flavor}-${catppuccinPalette.accent}-standard"
    export XCURSOR_THEME="catppuccin-${catppuccinPalette.flavor}-${catppuccinPalette.accent}-cursors"
    export XCURSOR_SIZE="32"
    export XDG_DATA_DIRS="${regreetDataDirs}"
    export XDG_CACHE_HOME="/var/cache/regreet"

    ${pkgs.cage}/bin/cage -d -m last -s -- ${greeterSession}
  '';
  wallpaperResolution =
    let
      res = host.display.primaryResolution;
    in
    if res != "" then noughtyLib.backgroundResolution res else "1920x1080";
  regreetOutputSetup = import ./regreet-output-setup { inherit pkgs; };
  greeterSession =
    if host.display.isMultiMonitor then
      lib.escapeShellArgs [
        "${regreetOutputSetup}/bin/regreet-output-setup"
        host.display.primary.output
        (toString host.display.primary.width)
        (toString host.display.primary.height)
        (toString host.display.primary.refresh)
        "${pkgs.dbus}/bin/dbus-run-session"
        "${pkgs.regreet}/bin/regreet"
      ]
    else
      "${pkgs.dbus}/bin/dbus-run-session ${pkgs.regreet}/bin/regreet";
in
lib.mkIf host.is.workstation {
  # Use Cage to run regreet
  environment = {
    systemPackages = [
      cursorPackage
      gtkThemePackage
      pkgs.papirus-icon-theme
      pkgs.wlr-randr
      regreetCage
    ];
  };
  programs = {
    regreet = {
      enable = true;
      cursorTheme = {
        name = "catppuccin-${catppuccinPalette.flavor}-${catppuccinPalette.accent}-cursors";
        package = cursorPackage;
      };
      settings = {
        appearance = {
          greeting_msg = "May ${noughtyLib.hostNameCapitalised} serve you well";
        };
        # https://docs.gtk.org/gtk4/enum.ContentFit.html
        background = {
          path = "/etc/backgrounds/Catppuccin-${wallpaperResolution}.png";
          fit = "Cover";
        };
        commands = {
          reboot = [
            "/run/current-system/sw/bin/systemctl"
            "reboot"
          ];
          poweroff = [
            "/run/current-system/sw/bin/systemctl"
            "poweroff"
          ];
        };
        GTK = lib.mkForce {
          application_prefer_dark_theme = catppuccinPalette.isDark;
          cursor_theme_name = "catppuccin-${catppuccinPalette.flavor}-${catppuccinPalette.accent}-cursors";
          font_name = "Work Sans 16";
          icon_theme_name = iconTheme;
          theme_name = "catppuccin-${catppuccinPalette.flavor}-${catppuccinPalette.accent}-standard";
        };
      };
    };
  };
  systemd.tmpfiles.rules = [
    "d /var/cache/regreet 0700 greeter greeter - -"
  ];
  security.pam.services.greetd.enableGnomeKeyring = true;
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "regreet-cage";
        user = "greeter";
      };
    };
  };
}
