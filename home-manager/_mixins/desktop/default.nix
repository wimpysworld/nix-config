{
  catppuccinPalette,
  config,
  desktop,
  lib,
  pkgs,
  username,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux;
  buttonLayout =
    if config.wayland.windowManager.hyprland.enable then ":appmenu" else ":close,minimize,maximize";
  clockFormat = "24h";
  cursorSize = 32;
  blues = [
    "blue"
    "sky"
    "sapphire"
    "lavender"
  ];
  pinks = [
    "pink"
    "rosewater"
    "flamingo"
  ];
  reds = [
    "red"
    "maroon"
  ];
  themeAccent =
    if lib.elem catppuccinPalette.accent blues then
      ""
    else if catppuccinPalette.accent == "green" then
      "-Green"
    else if catppuccinPalette.accent == "peach" then
      "-Orange"
    else if lib.elem catppuccinPalette.accent pinks then
      "-Pink"
    else if catppuccinPalette.accent == "mauve" then
      "-Purple"
    else if lib.elem catppuccinPalette.accent reds then
      "-Red"
    else if catppuccinPalette.accent == "teal" then
      "-Teal"
    else if catppuccinPalette.accent == "yellow" then
      "-Yellow"
    else
      "";
  cursorPackage =
    pkgs.catppuccin-cursors."${catppuccinPalette.flavor}${
      lib.toUpper (builtins.substring 0 1 catppuccinPalette.accent)
    }${builtins.substring 1 (-1) catppuccinPalette.accent}";
  gtkCatppuccinThemeName = "catppuccin-${config.catppuccin.flavor}-${config.catppuccin.accent}-standard";
  gtkCatppuccinThemePackage = (
    pkgs.catppuccin-gtk.override {
      accents = [ "${config.catppuccin.accent}" ];
      size = "standard";
      variant = config.catppuccin.flavor;
    }
  );
  gtkColloidThemeName = "Colloid${themeAccent}${catppuccinPalette.themeShade}-Catppuccin";
  gtkColloidThemePackage = pkgs.colloid-gtk-theme.override {
    colorVariants = [
      "standard"
      "light"
      "dark"
    ];
    sizeVariants = [
      "standard"
      "compact"
    ];
    themeVariants = [ "all" ];
    tweaks = [ "catppuccin" ];
  };
  iconThemeName = if catppuccinPalette.isDark then "Papirus-Dark" else "Papirus-Light";
  iconThemePackage =
    if (isLinux) then
      pkgs.catppuccin-papirus-folders.override {
        flavor = config.catppuccin.flavor;
        accent = config.catppuccin.accent;
      }
    else
      null;
in
{
  # import the DE specific configuration and any user specific desktop configuration
  imports = [
    ./apps
    ./wayfire
  ]
  ++ lib.optional (builtins.pathExists (./. + "/${desktop}")) ./${desktop}
  ++ lib.optional (builtins.pathExists (
    ./. + "/${desktop}/${username}/default.nix"
  )) ./${desktop}/${username};

  catppuccin = {
    cursors.enable = isLinux;
    kvantum.enable = config.qt.enable;
  };

  dconf = lib.mkIf isLinux {
    settings = with lib.hm.gvariant; {
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

  # Authrorize X11 access in Distrobox
  home = lib.mkIf isLinux {
    file = {
      ".distroboxrc".text = ''${pkgs.xorg.xhost}/bin/xhost +si:localuser:$USER'';
    };
    packages = [
      pkgs.kdePackages.qt6ct
      pkgs.kdePackages.qtstyleplugin-kvantum
      pkgs.libsForQt5.qt5ct
      pkgs.libsForQt5.qtstyleplugin-kvantum
      pkgs.notify-desktop
      pkgs.wlr-randr
      pkgs.wl-clipboard
      pkgs.wtype
    ];
    pointerCursor = {
      dotIcons.enable = true;
      gtk.enable = true;
      hyprcursor = {
        enable = config.wayland.windowManager.hyprland.enable;
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

  gtk = {
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
      extraConfig = {
        gtk-decoration-layout = "${buttonLayout}";
      };
    };
    iconTheme = {
      name = iconThemeName;
      package = iconThemePackage;
    };
    theme = {
      name = gtkCatppuccinThemeName;
      package = gtkCatppuccinThemePackage;
    };
  };

  qt = lib.mkIf isLinux {
    enable = true;
    platformTheme = {
      name = config.qt.style.name;
    };
    style = {
      name = "kvantum";
    };
  };

  services = lib.mkIf isLinux {
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

  xdg = {
    autostart = {
      enable = true;
    };
    configFile = {
      qt5ct = {
        target = "qt5ct/qt5ct.conf";
        text = lib.generators.toINI { } {
          Appearance = {
            icon_theme = config.gtk.iconTheme.name;
          };
        };
      };
      qt6ct = {
        target = "qt6ct/qt6ct.conf";
        text = lib.generators.toINI { } {
          Appearance = {
            icon_theme = config.gtk.iconTheme.name;
          };
        };
      };
    };
    desktopEntries = lib.mkIf isLinux {
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
    portal = lib.mkIf isLinux {
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
        pkgs.xorg.xset
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
