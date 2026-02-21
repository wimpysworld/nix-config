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
  # Reference for setting display configuration for cage
  # - https://github.com/cage-kiosk/cage/issues/304
  # - https://github.com/cage-kiosk/cage/issues/257
  regreetCage = pkgs.writeShellScriptBin "regreet-cage" ''
    # Start regreet in a Wayland kiosk using Cage
    function cleanup() {
      ${pkgs.procps}/bin/pkill kanshi || true
    }
    trap cleanup EXIT

    export GTK_THEME="catppuccin-${catppuccinPalette.flavor}-${catppuccinPalette.accent}-standard"
    export XCURSOR_THEME="catppuccin-${catppuccinPalette.flavor}-${catppuccinPalette.accent}-cursors"
    export XCURSOR_SIZE="32"
    export XDG_DATA_DIRS="${gtkThemePackage}/share:${cursorPackage}/share:${pkgs.papirus-icon-theme}/share:$XDG_DATA_DIRS"

    # If there is a kanshi profile for regreet, use it.
    KANSHI_REGREET="$(${pkgs.coreutils}/bin/head --lines 1 --quiet /etc/kanshi/regreet 2>/dev/null | ${pkgs.gnused}/bin/sed 's/ //g')"
    if [ -n "$KANSHI_REGREET" ]; then
      ${pkgs.cage}/bin/cage -d -m last -s -- sh -c \
        '${pkgs.kanshi}/bin/kanshi --config /etc/kanshi/regreet & \
         ${pkgs.dbus}/bin/dbus-run-session ${pkgs.regreet}/bin/regreet'
    else
      ${pkgs.cage}/bin/cage -d -m last -s -- ${pkgs.dbus}/bin/dbus-run-session ${pkgs.regreet}/bin/regreet
    fi
  '';
  wallpaperResolution =
    let
      res = host.display.primaryResolution;
    in
    if res != "" then res else "1920x1080";
  # Kanshi profile for regreet: disable non-primary displays, enable primary.
  # Order matters: Cage -m last uses the last enabled output.
  # Single-monitor hosts need no kanshi profile; Cage handles one output fine.
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
  # Use Cage to run regreet
  environment = {
    etc = {
      "kanshi/regreet".text = kanshiProfile;
    };
    systemPackages = [
      cursorPackage
      gtkThemePackage
      pkgs.papirus-icon-theme
      regreetCage
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
          cursor_theme_name = "catppuccin-${catppuccinPalette.flavor}-${catppuccinPalette.accent}-cursors";
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
        command = "regreet-cage";
        user = "greeter";
      };
    };
  };
}
