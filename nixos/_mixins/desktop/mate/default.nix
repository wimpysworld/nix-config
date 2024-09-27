{
  lib,
  isInstall,
  pkgs,
  ...
}:
{
  environment = {
    mate.excludePackages = with pkgs; [
      mate.caja-dropbox
      mate.eom
      mate.mate-themes
      mate.mate-netbook
      mate.mate-icon-theme
      mate.mate-backgrounds
      mate.mate-icon-theme-faenza
    ];

    systemPackages =
      with pkgs;
      lib.optionals isInstall [
        evolutionWithPlugins
        gnome.gucharmap
        gnome-firmware
      ];
  };

  programs = {
    dconf.profiles.user.databases = [
      {
        settings = with lib.gvariant; {
          "org/gnome/charmap" = {
            font = "Work Sans 22";
          };

          "org/gnome/desktop/interface" = {
            clock-format = "24h";
            color-scheme = "prefer-dark";
            cursor-size = mkInt32 32;
            cursor-theme = "catppuccin-mocha-blue-cursors";
            document-font-name = "Work Sans 12";
            font-name = "Work Sans 12";
            gtk-theme = "catppuccin-mocha-blue-standard";
            icon-theme = "Papirus-Dark";
            monospace-font-name = "FiraCode Nerd Font Mono Medium 13";
            text-scaling-factor = mkDouble 1.0;
          };

          "org/gnome/desktop/wm/preferences" = {
            button-layout = "close,minimize,maximize";
            theme = "catppuccin-mocha-blue-standard";
            titlebar-font = "Work Sans Semi-Bold 12";
            titlebar-uses-system-font = false;
          };

          "org/gnome/evolution/mail" = {
            monospace-font = "FiraCode Nerd Font Mono Medium 13";
            search-gravatar-for-photo = true;
            show-sender-photo = true;
            variable-width-font = "Work Sans 12";
          };

          "org/gnome/evolution/plugin/external-editor" = {
            command = "pluma";
          };

          "org/gtk/settings/file-chooser" = {
            sort-directories-first = true;
          };

          "org/mate/applications-office/calendar" = {
            exec = "evolution";
          };

          "org/mate/applications-office/tasks" = {
            exec = "evolution";
          };

          "org/mate/caja/desktop" = {
            computer-icon-visible = false;
            font = "Work Sans Medium 12";
            home-icon-visible = true;
            trash-icon-visible = false;
          };

          "org/mate/caja/extensions" = {
            disabled-extensions = [
              "libcaja-gksu"
              "libcaja-wallpaper"
              "libcaja-share"
              "libcaja-sendto"
            ];
          };

          "org/mate/caja/list-view" = {
            default-zoom-level = "small";
          };

          "org/mate/caja/preferences" = {
            date-format = "iso";
            default-folder-view = "list-view";
          };

          "org/mate/dictionary" = {
            print-font = "Work Sans 12";
          };

          "org/mate/disk-usage-analyzer/ui" = {
            statusbar-visible = true;
          };

          "org/mate/desktop/applications/messager" = {
            exec = "telegram-desktop";
          };

          "org/mate/desktop/applications/terminal" = {
            exec = "mate-terminal";
          };

          "org/mate/desktop/background" = {
            picture-filename = "";
            primary-color = "rgb(192,97,203)";
            secondary-color = "rgb(28,113,216)";
          };

          "org/mate/desktop/font-rendering" = {
            antialiasing = "rgba";
            hinting = "slight";
            rgba-order = "rgb";
          };

          "org/mate/desktop/interface" = {
            document-font-name = "Work Sans 12";
            font-name = "Work Sans 12";
            gtk-decoration-layout = "close,minimize,maximize";
            gtk-theme = "catppuccin-mocha-blue-standard";
            gtk-color-scheme = "tooltip_fg_color:#ffffff\ntooltip_bg_color:#343434";
            icon-theme = "Papirus-Dark";
            monospace-font-name = "FiraCode Nerd Font Mono Medium 13";
          };

          "org/mate/desktop/peripherals/mouse" = {
            cursor-size = mkInt32 48;
            cursor-theme = "catppuccin-mocha-blue-cursors";
          };

          "org/mate/desktop/peripherals/touchpad" = {
            disable-while-typing = true;
            tap-to-click = true;
            three-finger-click = mkInt32 0;
            two-finger-click = mkInt32 0;
          };

          "org/mate/desktop/session" = {
            idle-delay = mkInt32 30;
          };

          "org/mate/desktop/sound" = {
            event-sounds = true;
            input-feedback-sounds = true;
            theme-name = "freedesktop";
          };

          "org/mate/eom/view" = {
            extrapolate = false;
            interpolate = false;
          };

          "org/mate/notification-daemon" = {
            theme = "slider";
          };

          "org/mate/marco/general" = {
            alt-tab-expand-to-fit-title = true;
            button-layout = "close,minimize,maximize";
            center-new-windows = false;
            compositing-manager = true;
            show-tab-border = false;
            theme = "catppuccin-mocha-blue-standard";
            titlebar-font = "Work Sans Semi-Bold 12";
          };

          "org/mate/marco/global-keybindings" = {
            run-command-1 = "<Mod4>l";
            run-command-2 = "<Shift>Print";
            run-command-3 = "<Mod4>e";
            run-command-4 = "<Mod4>t";
            run-command-5 = "<Mod4>i";
            run-command-6 = "<Mod4>s";
            run-command-7 = "<Control><Shift>Escape";
            run-command-8 = "<Mod4>Pause";
            run-command-terminal = "<Control><Alt>t";
            switch-panels = "disabled";
            switch-windows = "<Alt>Tab";
            switch-windows-all = "<Control><Alt>Tab";
            switch-windows-all-backward = "<Control><Alt><Shift>Tab";
            switch-windows-backward = "<Alt><Shift>Tab";
            switch-to-workspace-1 = "<Control><Alt>1";
            switch-to-workspace-2 = "<Control><Alt>2";
            switch-to-workspace-3 = "<Control><Alt>3";
            switch-to-workspace-4 = "<Control><Alt>4";
            switch-to-workspace-5 = "<Control><Alt>5";
            switch-to-workspace-6 = "<Control><Alt>6";
            switch-to-workspace-7 = "<Control><Alt>7";
            switch-to-workspace-8 = "<Control><Alt>8";
          };

          "org/mate/marco/keybinding-commands" = {
            command-1 = "mate-screensaver-command --lock";
            command-2 = "/bin/sh -c \"sleep 0.1; mate-screenshot --area\"";
            command-3 = "caja";
            command-4 = "alacritty";
            command-5 = "mate-control-center";
            command-6 = "mate-search-tool";
            command-7 = "mate-system-monitor -p";
            command-8 = "mate-system-monitor -s";
          };

          "org/mate/marco/window-keybindings" = {
            maximize = "<Mod4>Up";
            move-to-center = "<Alt><Mod4>c";
            tile-to-corner-ne = "<Alt><Mod4>Right";
            tile-to-corner-nw = "<Alt><Mod4>Left";
            tile-to-corner-se = "<Shift><Alt><Mod4>Right";
            tile-to-corner-sw = "<Shift><Alt><Mod4>Left";
            tile-to-side-e = "<Mod4>Right";
            tile-to-side-w = "<Mod4>Left";
            toggle-shaded = "<Control><Alt>s";
            unmaximize = "<Mod4>Down";
          };

          "org/mate/maximus" = {
            no-maximize = true;
            undecorate = false;
          };

          "org/mate/media-handling" = {
            autorun-x-content-start-app = [
              "x-content/software"
              "x-content/video-bluray.xml"
              "x-content/video-dvd.xml"
              "x-content/video-hddvd.xml"
              "x-content/video-svcd.xml"
              "x-content/video-vcd.xml"
            ];
          };

          "org/mate/panel" = {
            enable-sni-support = true;
            show-program-list = true;
          };

          "org/mate/panel/menubar" = {
            icon-name = "start-here-symbolic";
          };

          "org/mate/panel/objects/workspace-switcher/prefs" = {
            display-workspace-names = true;
          };

          "org/mate/pluma" = {
            auto-indent = true;
            bracket-matching = true;
            color-scheme = "catppuccin";
            display-line-numbers = true;
            display-right-margin = true;
            display-overview-map = true;
            editor-font = "FiraCode Nerd Font Mono Medium 13";
            highlight-current-line = true;
            insert-spaces = true;
            print-font-body-pango = "FiraCode Nerd Font Mono Medium 10";
            print-font-header-pango = "Work Sans 11";
            print-font-numbers-pango = "Work Sans 8";
          };

          "org/mate/power-manager" = {
            button-power = "interactive";
            sleep-computer-ac = mkInt32 0;
            sleep-display-ac = mkInt32 3600;
          };

          "org/mate/screensaver" = {
            lock-delay = mkInt32 1;
            mode = "single";
            themes = [ "screensavers-footlogo-floaters" ];
          };

          "org/mate/settings-daemon/plugins/media-keys" = {
            magnifier = "<Alt><Mod4>m";
            on-screen-keyboard = "<Alt><Mod4>k";
            screenreader = "<Alt><Mod4>s";
          };

          "org/mate/stickynotes" = {
            default-font = "Work Sans Medium 10";
          };

          "org/mate/system-monitor" = {
            cpu-color0 = "#9A0606";
            cpu-color1 = "#B42828";
            cpu-color2 = "#CD5050";
            cpu-color3 = "#E67F7F";
            cpu-color4 = "#FFB4B4";
            cpu-color5 = "#9A5306";
            cpu-color6 = "#B47028";
            cpu-color7 = "#CD8F50";
            cpu-color8 = "#E6B37F";
            cpu-color9 = "#FFDBB5";
            cpu-color10 = "#6B9A06";
            cpu-color11 = "#86B428";
            cpu-color12 = "#A4CD50";
            cpu-color13 = "#C4E67F";
            cpu-color14 = "#E6FFB3";
            cpu-color15 = "#066B9A";
            cpu-color16 = "#2886B4";
            cpu-color17 = "#50A5CD";
            cpu-color18 = "#7FC4E6";
            cpu-color19 = "#B3E6FF";
            cpu-color20 = "#21069A";
            cpu-color21 = "#4028B4";
            cpu-color22 = "#6550CD";
            cpu-color23 = "#907FE6";
            cpu-color24 = "#C0B4FF";
            cpu-color25 = "#870087";
            cpu-color26 = "#BC00BC";
            cpu-color27 = "#F100F1";
            cpu-color28 = "#FF4FFF";
            cpu-color29 = "#FF87FF";
            cpu-color30 = "#C4A000";
            cpu-color31 = "#EDD400";
            show-tree = true;
            solaris-mode = false;
          };

          "org/mate/terminal/profile" = {
            allow-bold = false;
            use-system-font = true;
          };
        };
      }
    ];
    evolution.enable = isInstall;
    gnome-disks.enable = isInstall;
    nm-applet = {
      enable = true;
      # When Indicator support for MATE is available in NixOS, this can be true
      indicator = false;
    };
    seahorse.enable = isInstall;
  };

  # Enable services to round out the desktop
  services = {
    blueman.enable = true;
    gnome.evolution-data-server.enable = lib.mkForce isInstall;
    gnome.gnome-keyring.enable = true;
    gvfs.enable = true;
    xserver = {
      enable = true;
      displayManager = {
        lightdm.enable = true;
        lightdm.greeters.gtk = {
          enable = true;
          cursorTheme.name = "catppuccin-mocha-blue-cursors";
          cursorTheme.package = pkgs.catppuccin-cursors.mochaBlue;
          cursorTheme.size = 32;
          iconTheme.name = "Papirus-Dark";
          iconTheme.package = pkgs.catppuccin-papirus-folders;
          theme.name = "catppuccin-mocha-blue-standard";
          theme.package = pkgs.catppuccin-gtk;
          indicators = [
            "~session"
            "~host"
            "~spacer"
            "~clock"
            "~spacer"
            "~a11y"
            "~power"
          ];
          # https://github.com/Xubuntu/lightdm-gtk-greeter/blob/master/data/lightdm-gtk-greeter.conf
          extraConfig = ''
            # background = Background file to use, either an image path or a color (e.g. #772953)
            font-name = Work Sans 12
            xft-antialias = true
            xft-dpi = 96
            xft-hintstyle = slight
            xft-rgba = rgb

            active-monitor = #cursor
            # position = x y ("50% 50%" by default)  Login window position
            # default-user-image = Image used as default user icon, path or #icon-name
            hide-user-image = false
            round-user-image = false
            highlight-logged-user = true
            panel-position = top
            clock-format = %a, %b %d  %H:%M
          '';
        };
      };
      desktopManager.mate.enable = true;
    };
  };
}
