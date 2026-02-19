{
  catppuccinPalette,
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  cursorPackage =
    pkgs.catppuccin-cursors."${catppuccinPalette.flavor}${
      lib.toUpper (builtins.substring 0 1 catppuccinPalette.accent)
    }${builtins.substring 1 (-1) catppuccinPalette.accent}";
  gtkThemePackage = (
    pkgs.catppuccin-gtk.override {
      accents = [ "${catppuccinPalette.accent}" ];
      variant = catppuccinPalette.flavor;
    }
  );
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
      ${pkgs.cage}/bin/cage -m last -s -- sh -c \
        '${pkgs.kanshi}/bin/kanshi --config /etc/kanshi/regreet & \
         ${pkgs.dbus}/bin/dbus-run-session ${pkgs.regreet}/bin/regreet'
    else
      ${pkgs.cage}/bin/cage -m last -s -- ${pkgs.dbus}/bin/dbus-run-session ${pkgs.regreet}/bin/regreet
    fi
  '';
  wallpaperResolutions = {
    bane = "2560x1600";
    vader = "2560x2880";
    phasma = "3440x1440";
    tanis = "1920x1200";
    felkor = "1920x1200";
    default = "1920x1080";
  };
  wallpaperResolution =
    wallpaperResolutions.${config.noughty.host.name} or wallpaperResolutions.default;
  # Kanshi profiles for regreet that just enable the primary display:
  # - Order is important
  # - The last enabled output is what cage will use via `-m last`
  kanshiProfiles = {
    phasma = ''
      profile {
        output DP-2 disable
        output HDMI-A-1 disable
        output DP-1 enable mode 3440x1440@100Hz position 0,1280 scale 1
      }
    '';
    vader = ''
      profile {
        output DP-3 disable
        output DP-2 disable
        output DP-1 enable mode 2560x2880@60Hz position 0,0 scale 1
      }
    '';
    default = "";
  };
in
lib.mkIf config.noughty.host.is.workstation {
  # Use Cage to run regreet
  environment = {
    etc = {
      "kanshi/regreet".text = kanshiProfiles.${config.noughty.host.name} or kanshiProfiles.default;
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
