{
  catppuccinPalette,
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
in
{
  # Import the DE specific configuration; each compositor gates itself internally
  imports = [
    ./apps
    ./compositor/hyprland
    ./compositor/wayfire
  ];

  config = lib.mkIf host.is.workstation (
    let
      buttonLayout =
        if config.wayland.windowManager.hyprland.enable then ":appmenu" else ":close,minimize,maximize";
      clockFormat = "24h";
      cursorSize = 32;
      gtkCatppuccinThemeName = "catppuccin-${config.catppuccin.flavor}-${config.catppuccin.accent}-standard";
      gtkCatppuccinThemePackage = pkgs.catppuccin-gtk.override {
        accents = [ "${config.catppuccin.accent}" ];
        size = "standard";
        variant = config.catppuccin.flavor;
      };
    in
    {
      catppuccin = {
        cursors.enable = host.is.linux;
        gtk.icon.enable = host.is.linux;
        kvantum.enable = config.qt.enable;
      };

      dconf = lib.mkIf host.is.linux {
        settings = {
          "org/gnome/desktop/interface" = {
            color-scheme = catppuccinPalette.preferShade;
            clock-format = clockFormat;
            cursor-size = cursorSize;
            cursor-theme = config.home.pointerCursor.name;
            document-font-name = config.gtk.font.name or "Work Sans 13";
            gtk-enable-primary-paste = true;
            gtk-theme = config.gtk.theme.name;
            icon-theme = config.gtk.iconTheme.name;
            monospace-font-name = "FiraCode Nerd Font Mono Medium 13";
            text-scaling-factor = 1.0;
          };

          "org/gnome/desktop/sound" = {
            theme-name = "freedesktop";
          };

          "org/gnome/desktop/wm/preferences" = {
            button-layout = "${buttonLayout}";
            theme = config.gtk.theme.name;
          };

          "org/gtk/gtk4/Settings/FileChooser" = {
            clock-format = clockFormat;
          };

          "org/gtk/Settings/FileChooser" = {
            clock-format = clockFormat;
          };
        };
      };

      home = lib.mkIf host.is.linux {
        packages = [
          pkgs.kdePackages.qt6ct
          pkgs.libsForQt5.qt5ct
          pkgs.notify-desktop
          pkgs.wlr-randr
          pkgs.wl-clipboard
          pkgs.wtype
        ];
        pointerCursor = {
          dotIcons.enable = true;
          gtk.enable = true;
          hyprcursor = {
            inherit (config.wayland.windowManager.hyprland) enable;
            size = cursorSize;
          };
          size = cursorSize;
          x11.enable = true;
        };
        sessionVariables = {
          GDK_BACKEND = "wayland,x11";
          MOZ_ENABLE_WAYLAND = "1";
          NIXOS_OZONE_WL = "1";
          QT_QPA_PLATFORM = "wayland;xcb";
          QT_STYLE_OVERRIDE = "kvantum";
          QT_WAYLAND_DISABLE_WINDOWDECORATION = if config.wayland.windowManager.hyprland.enable then 1 else 0;
        };
      };

      gtk = lib.mkIf host.is.linux {
        enable = true;
        font = {
          name = "Work Sans";
          size = 13;
          package = pkgs.work-sans;
        };
        gtk2 = {
          configLocation = "${config.xdg.configHome}/.gtkrc-2.0";
          extraConfig = ''
            gtk-application-prefer-dark-theme = "${catppuccinPalette.isDarkAsIntString}"
            gtk-button-images = 1
            gtk-decoration-layout = "${buttonLayout}"
          '';
        };
        gtk3 = {
          extraConfig = {
            gtk-application-prefer-dark-theme = catppuccinPalette.isDark;
            gtk-button-images = 1;
            gtk-decoration-layout = "${buttonLayout}";
          };
        };
        gtk4 = {
          # Mirror `gtk.theme` into GTK4; the 26.05 default stopped doing this.
          inherit (config.gtk) theme;
          extraConfig = {
            gtk-decoration-layout = "${buttonLayout}";
          };
        };
        theme = {
          name = gtkCatppuccinThemeName;
          package = gtkCatppuccinThemePackage;
        };
      };

      qt = lib.mkIf host.is.linux {
        enable = true;
        platformTheme = {
          inherit (config.qt.style) name;
        };
        qt5ctSettings = {
          Appearance = {
            icon_theme = config.gtk.iconTheme.name;
          };
        };
        qt6ctSettings = {
          Appearance = {
            icon_theme = config.gtk.iconTheme.name;
          };
        };
        style = {
          name = "kvantum";
        };
      };

      services = lib.mkIf host.is.linux {
        gnome-keyring = {
          enable = true;
        };
        gpg-agent.pinentry.package = lib.mkForce pkgs.pinentry-gnome3;
        mpris-proxy = {
          # https://nixos.wiki/wiki/Bluetooth#Using_Bluetooth_headsets_with_PulseAudio
          enable = true;
        };
        polkit-gnome = {
          enable = true;
        };
        udiskie = {
          enable = true;
          automount = false;
          tray = "auto";
          notify = true;
        };
      };

      xdg = lib.mkIf host.is.linux {
        autostart = {
          enable = true;
        };
        desktopEntries = {
          kvantummanager = {
            name = "Kvantum Manager";
            noDisplay = true;
          };
          nvtop = {
            name = "nvtop";
            noDisplay = true;
          };
          qt5ct = {
            name = "Qt5 Settings";
            noDisplay = true;
          };
          qt6ct = {
            name = "Qt6 Settings";
            noDisplay = true;
          };
        };
        portal = {
          config = {
            common = {
              default =
                if config.wayland.windowManager.hyprland.enable then
                  [
                    "hyprland"
                    "gtk"
                  ]
                else
                  [ "gtk" ];
              # For "Open With" dialogs. GTK portal provides the familiar GNOME-style app chooser.
              "org.freedesktop.impl.portal.AppChooser" = [ "gtk" ];
              "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
              # Inhibit is useful for preventing sleep during media playback
              "org.freedesktop.impl.portal.Inhibit" = [ "gtk" ];
              # GTK portal gives you proper print dialogs.
              "org.freedesktop.impl.portal.Print" = [ "gtk" ];
              # Security/credentials
              "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
              # GTK portal provides desktop settings that GTK apps query (fonts, themes, colour schemes).
              "org.freedesktop.impl.portal.Settings" = [ "gtk" ];
            };
          };
          # Add xset to satisfy xdg-screensaver requirements
          configPackages = [
            pkgs.xset
          ];
          enable = true;
          extraPortals = [
            pkgs.xdg-desktop-portal
            pkgs.xdg-desktop-portal-gtk
          ]
          ++ lib.optionals config.wayland.windowManager.hyprland.enable [
            pkgs.xdg-desktop-portal-hyprland
          ]
          ++ lib.optionals config.wayland.windowManager.wayfire.enable [
            pkgs.xdg-desktop-portal-wlr
          ];
          xdgOpenUsePortal = true;
        };
      };
    }
  );
}
