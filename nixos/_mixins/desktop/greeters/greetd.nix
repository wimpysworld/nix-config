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
  cursorThemeName = "catppuccin-${catppuccinPalette.flavor}-${catppuccinPalette.accent}-cursors";
  cursorSize = 32;
  cursorPackage =
    config.catppuccin.sources.cursors."${catppuccinPalette.flavor}${lib.toSentenceCase catppuccinPalette.accent}";
  gtkThemePackage = pkgs.catppuccin-gtk.override {
    accents = [ "${catppuccinPalette.accent}" ];
    variant = catppuccinPalette.flavor;
  };
  iconTheme = if catppuccinPalette.isDark then "Papirus-Dark" else "Papirus-Light";
  # Compositor choice: labwc, not cage.
  # GTK4 >= 4.16 on Wayland no longer loads Xcursor themes from disk; it only
  # renders cursors via wp_cursor_shape_v1 (offloaded to the compositor) or its
  # bundled GResource fallback. cage 0.3.0 does not advertise wp_cursor_shape_v1,
  # so regreet's cursor reverts to the GTK4 default on pointer-enter. labwc does
  # advertise it, letting the compositor render the themed cursor from
  # XCURSOR_THEME. See https://gitlab.gnome.org/GNOME/gtk/-/blob/4.22.4/gdk/wayland/gdkcursor-wayland.c
  regreetLabwc = pkgs.writeShellScriptBin "regreet-labwc" ''
    function cleanup() {
      ${pkgs.procps}/bin/pkill kanshi || true
    }
    trap cleanup EXIT

    export GTK_THEME="catppuccin-${catppuccinPalette.flavor}-${catppuccinPalette.accent}-standard"
    export XCURSOR_PATH="${cursorPackage}/share/icons''${XCURSOR_PATH:+:$XCURSOR_PATH}"
    export XDG_DATA_DIRS="${gtkThemePackage}/share:${cursorPackage}/share:${pkgs.papirus-icon-theme}/share:$XDG_DATA_DIRS"

    # If there is a kanshi profile for regreet, use it.
    KANSHI_REGREET="$(${pkgs.coreutils}/bin/head --lines 1 --quiet /etc/kanshi/regreet 2>/dev/null | ${pkgs.gnused}/bin/sed 's/ //g')"
    if [ -n "$KANSHI_REGREET" ]; then
      ${pkgs.labwc}/bin/labwc -C /etc/labwc-greeter -S '${pkgs.kanshi}/bin/kanshi --config /etc/kanshi/regreet & ${pkgs.dbus}/bin/dbus-run-session ${pkgs.regreet}/bin/regreet'
    else
      ${pkgs.labwc}/bin/labwc -C /etc/labwc-greeter -S '${pkgs.dbus}/bin/dbus-run-session ${pkgs.regreet}/bin/regreet'
    fi
  '';
  wallpaperResolution =
    let
      res = host.display.primaryResolution;
    in
    if res != "" then res else "1920x1080";
  # Kanshi profile for regreet: disable non-primary displays, enable primary.
  # Single-monitor hosts need no kanshi profile
  kanshiProfile =
    if !host.display.isMultiMonitor then
      ""
    else
      let
        inherit (host.display) primary;
        nonPrimary = lib.filter (d: d.output != primary.output) host.displays;
        disableLines = map (d: "    output ${d.output} disable") nonPrimary;
        enableLine = "    output ${primary.output} enable mode ${toString primary.width}x${toString primary.height}@${toString primary.refresh}Hz position 0,0 scale 1";
      in
      ''
        profile {
        ${lib.concatStringsSep "\n" disableLines}
        ${enableLine}
        }
      '';
in
lib.mkIf host.is.workstation {
  environment = {
    etc = {
      "kanshi/regreet".text = kanshiProfile;
      "labwc-greeter/environment".text = ''
        XCURSOR_THEME=${cursorThemeName}
        XCURSOR_SIZE=${toString cursorSize}
      '';
      # Wildcard identifier sidesteps the app_id race (set after first map);
      # explicit Maximize + SetDecorations are deterministic vs ToggleFullscreen.
      "labwc-greeter/rc.xml".text = ''
        <?xml version="1.0"?>
        <labwc_config>
          <core>
            <decoration>server</decoration>
            <gap>0</gap>
            <xwaylandPersistence>no</xwaylandPersistence>
          </core>
          <theme>
            <cornerRadius>0</cornerRadius>
            <dropShadows>no</dropShadows>
            <keepBorder>no</keepBorder>
            <maximizedDecoration>none</maximizedDecoration>
          </theme>
          <windowRules>
            <windowRule identifier="*" matchOnce="true">
              <skipTaskbar>yes</skipTaskbar>
              <skipWindowSwitcher>yes</skipWindowSwitcher>
              <serverDecoration>no</serverDecoration>
              <action name="Maximize"/>
              <action name="SetDecorations" decorations="none"/>
            </windowRule>
          </windowRules>
        </labwc_config>
      '';
    };
    systemPackages = [
      cursorPackage
      gtkThemePackage
      pkgs.papirus-icon-theme
      regreetLabwc
    ];
  };
  programs = {
    regreet = {
      enable = true;
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
          font_name = "Work Sans 16";
          icon_theme_name = iconTheme;
          theme_name = "catppuccin-${catppuccinPalette.flavor}-${catppuccinPalette.accent}-standard";
        };
      };
    };
  };
  security.pam.services.greetd.enableGnomeKeyring = true;
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "regreet-labwc";
        user = "greeter";
      };
    };
  };
}
