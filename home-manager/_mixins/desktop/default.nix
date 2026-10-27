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
  # Each imported module gates itself internally.
  imports = [
    ./apps
    ./compositor
    ./removable-media
  ];

  config = lib.mkIf host.is.workstation (
    let
      compositor =
        if host.is.linux && host.is.workstation then
          lib.attrByPath [ host.desktop ] null (import ../../../lib/wayland-compositors.nix).compositors
        else
          null;
      clientSideDecorations = compositor == null || compositor.capabilities.clientSideDecorations;
      buttonLayout = if clientSideDecorations then ":minimize,maximize,close" else ":appmenu";
      clockFormat = "24h";
      cursorSize = 32;
      monospaceFont = {
        name = "FiraCode Nerd Font Mono";
        size = 13;
        weight = "Medium";
      };
      # qtct parses fonts with QFont::fromString. Qt 5 writes 10 fields with
      # weights from 0 to 99. Qt 6 writes 16 fields with OpenType weights.
      qtFontWeights = {
        Regular = {
          qt5 = 50;
          qt6 = 400;
        };
        Medium = {
          qt5 = 57;
          qt6 = 500;
        };
      };
      qtctFont =
        qt: name: size: weight:
        let
          fields = [
            name
            (toString size)
            "-1"
            "5"
            (toString qtFontWeights.${weight}.${qt})
          ]
          ++ lib.replicate 5 "0"
          ++ lib.optionals (qt == "qt6") (lib.replicate 5 "0" ++ [ "1" ]);
        in
        ''"${lib.concatStringsSep "," fields}"'';
      # Kvantum keeps its own palette, because custom_palette is off. Qt file
      # dialogs go through the portal, which portalRouting sends to GTK.
      qtctSettings = qt: {
        Appearance = {
          custom_palette = false;
          icon_theme = config.gtk.iconTheme.name;
          standard_dialogs = "xdgdesktopportal";
          style = config.qt.style.name;
        };
        Fonts = {
          fixed = qtctFont qt monospaceFont.name monospaceFont.size monospaceFont.weight;
          general = qtctFont qt config.gtk.font.name config.gtk.font.size "Regular";
        };
      };
      gtkCatppuccinThemeName = "catppuccin-${config.catppuccin.flavor}-${config.catppuccin.accent}-standard";
      # Home Manager issue 7124: until nixpkgs 26.11, the Home Manager portal
      # directory hides every backend that only NixOS installs. Keep GTK here
      # always, because the NixOS portal stub lists it.
      # GNOME Keyring serves the Secret portal through the daemon that already
      # owns org.freedesktop.secrets. Its UseIn=gnome line does not matter,
      # because portalRouting selects it explicitly.
      portalBackends = {
        gtk = pkgs.xdg-desktop-portal-gtk;
        inherit (pkgs) gnome-keyring;
      }
      // lib.optionalAttrs (compositor != null) {
        ${compositor.portal.backend} = pkgs.${compositor.portal.packageAttr};
      };
      portalRouting = {
        default = lib.optional (compositor != null) compositor.portal.backend ++ [ "gtk" ];
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
      }
      // lib.optionalAttrs (compositor != null) {
        "org.freedesktop.impl.portal.ScreenCast" = [ compositor.portal.backend ];
        "org.freedesktop.impl.portal.Screenshot" = [ compositor.portal.backend ];
      };
      # Without NixOS, nothing else registers the portal units and D-Bus
      # services with the user manager and the session bus.
      portalPackages = lib.optionals config.targets.genericLinux.enable (
        [ pkgs.xdg-desktop-portal ] ++ builtins.attrValues portalBackends
      );
      # Login shells read home.sessionVariables. The systemd user manager and
      # D-Bus activation read systemd.user.sessionVariables, so apps that
      # start through the portal, XDG autostart or D-Bus need both.
      desktopSessionVariables = lib.mapAttrs (_: lib.mkDefault) (
        {
          GDK_BACKEND = "wayland,x11";
          MOZ_ENABLE_WAYLAND = "1";
          NIXOS_OZONE_WL = "1";
          QT_QPA_PLATFORM = "wayland;xcb";
          QT_WAYLAND_DISABLE_WINDOWDECORATION = if clientSideDecorations then "0" else "1";
        }
        // lib.optionalAttrs (compositor != null) {
          DESKTOP_SESSION = lib.toLower compositor.launcher.desktopNames;
          XDG_SESSION_DESKTOP = lib.toLower compositor.launcher.desktopNames;
        }
      );
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
            monospace-font-name = "${monospaceFont.name} ${monospaceFont.weight} ${toString monospaceFont.size}";
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
          pkgs.fyi
          pkgs.wlr-randr
          pkgs.wl-clipboard
          pkgs.wtype
        ];
        pointerCursor = {
          dotIcons.enable = true;
          gtk.enable = true;
          size = cursorSize;
          x11.enable = true;
        };
        sessionVariables = desktopSessionVariables;
      };

      systemd.user.sessionVariables = lib.mkIf host.is.linux (
        desktopSessionVariables
        // lib.optionalAttrs config.xdg.portal.xdgOpenUsePortal {
          # The Home Manager portal module sets this for login shells only.
          NIXOS_XDG_OPEN_USE_PORTAL = lib.mkDefault "1";
        }
      );

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

      # qtct is the Qt platform theme. It gives Qt the GTK icon theme and
      # fonts, and portal file dialogs. Kvantum is the widget style, with the
      # Catppuccin theme from catppuccin.kvantum. Home Manager installs qt5ct,
      # qt6ct and both Kvantum plugins, and exports QT_QPA_PLATFORMTHEME=qt5ct,
      # which both plugins accept. It also exports QT_STYLE_OVERRIDE from
      # qt.style.name. Keep that, because apps that skip qtct still get Kvantum.
      qt = lib.mkIf host.is.linux {
        enable = true;
        platformTheme = {
          name = "qtct";
        };
        qt5ctSettings = qtctSettings "qt5";
        qt6ctSettings = qtctSettings "qt6";
        style = {
          name = "kvantum";
        };
      };

      services = lib.mkIf host.is.linux {
        # Home Manager runs the keyring daemon on every Linux host. The system
        # only unlocks it with the login password: on NixOS the greetd PAM
        # service does, and on generic Linux libpam-gnome-keyring does.
        gnome-keyring = {
          enable = true;
        };
        mpris-proxy = {
          # https://nixos.wiki/wiki/Bluetooth#Using_Bluetooth_headsets_with_PulseAudio
          enable = true;
        };
        # NetworkManager is enabled on every workstation. The service waits for
        # tray.target, which Waybar provides.
        network-manager-applet = {
          enable = true;
        };
        polkit-gnome = {
          enable = true;
        };
      };

      dbus.packages = portalPackages;
      systemd.user.packages = portalPackages;
      # Bind the polkit agent to the selected compositor session target, as
      # the other session services do. The Home Manager module uses
      # graphical-session.target, so these values replace its own.
      systemd.user.services.polkit-gnome = lib.mkIf host.is.linux (
        let
          sessionTarget = if compositor == null then "graphical-session.target" else compositor.sessionTarget;
        in
        {
          Unit = {
            After = lib.mkForce [ sessionTarget ];
            PartOf = lib.mkForce [ sessionTarget ];
          };
          Install.WantedBy = lib.mkForce [ sessionTarget ];
        }
      );

      # Start tray applets such as nm-applet with --indicator, because the
      # Waybar tray shows only StatusNotifierItem icons.
      xsession.preferStatusNotifierItems = lib.mkIf host.is.linux true;

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
        configFile = {
          "electron-flags.conf".text = ''
            --enable-features=AcceleratedVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL,AcceleratedVideoEncoder,VaapiIgnoreDriverChecks
          '';
        }
        // lib.optionalAttrs (compositor != null && compositor.portal.backend == "wlr") {
          # NixOS passed an empty settings file to xdg-desktop-portal-wlr
          # through --config. The backend reads this file by default, which
          # keeps those defaults without a NixOS service override.
          "xdg-desktop-portal-wlr/config".text = lib.generators.toINI { } { };
        };
        # On hosts without NixOS, the frontend searches this directory for
        # backends first. Each portal name matches its .portal file name.
        dataFile = lib.mkIf config.targets.genericLinux.enable (
          lib.mapAttrs' (
            name: package:
            lib.nameValuePair "xdg-desktop-portal/portals/${name}.portal" {
              source = "${package}/share/xdg-desktop-portal/portals/${name}.portal";
            }
          ) portalBackends
        );
        portal = {
          config = {
            common = portalRouting;
          }
          // lib.optionalAttrs (compositor != null) {
            # The frontend matches the lower-case XDG_CURRENT_DESKTOP value.
            ${lib.toLower compositor.launcher.desktopNames} = portalRouting;
          };
          # Add xset to satisfy xdg-screensaver requirements
          configPackages = [
            pkgs.xset
          ];
          enable = true;
          extraPortals = builtins.attrValues portalBackends;
          xdgOpenUsePortal = false;
        };
      };
    }
  );
}
