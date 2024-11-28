{
  isInstall,
  lib,
  pkgs,
  ...
}:
{
  environment = {
    pantheon.excludePackages = with pkgs; [
      pantheon.elementary-calculator
      pantheon.elementary-camera
      pantheon.elementary-code
      pantheon.elementary-music
      pantheon.elementary-photos
      pantheon.elementary-videos
      pantheon.epiphany
    ];

    # App indicator
    # - https://discourse.nixos.org/t/anyone-with-pantheon-de/28422
    # - https://github.com/NixOS/nixpkgs/issues/144045#issuecomment-992487775
    pathsToLink = [ "/libexec" ];

    systemPackages =
      with pkgs;
      lib.optionals isInstall [
        pantheon-tweaks
        pick-colour-picker
      ];
  };

  programs = {
    dconf.profiles.user.databases = [
      {
        settings = with lib.gvariant; {
          "com/github/stsdc/monitor/settings" = {
            background-state = true;
            indicator-state = true;
            indicator-cpu-state = false;
            indicator-gpu-state = false;
            indicator-memory-state = false;
            indicator-network-download-state = true;
            indicator-network-upload-state = true;
            indicator-temperature-state = true;
          };

          "desktop/ibus/panel" = {
            show-icon-on-systray = false;
            use-custom-font = true;
            custom-font = "Work Sans 10";
          };

          "desktop/ibus/panel/emoji" = {
            font = "Noto Color Emoji 16";
          };

          "io/elementary/code/saved-state" = {
            outline-visible = true;
          };

          "io/elementary/desktop/agent-geoclue2" = {
            location-enabled = true;
          };

          "io/elementary/desktop/wingpanel" = {
            use-transparency = false;
          };

          "io/elementary/desktop/wingpanel/datetime" = {
            clock-format = "24h";
          };

          "io/elementary/desktop/wingpanel/sound" = {
            max-volume = mkDouble 100.0;
          };

          "io/elementary/files/preferences" = {
            date-format = "iso";
            restore-tabs = false;
            singleclick-select = true;
          };

          "io/elementary/notifications/applications/gala-other" = {
            remember = false;
            sounds = false;
          };

          "io/elementary/settings-daemon/datetime" = {
            show-weeks = true;
          };

          "io/elementary/settings-daemon/housekeeping" = {
            cleanup-downloads-folder = false;
          };

          "io/elementary/terminal/settings" = {
            audible-bell = false;
            background = "rgb(30,30,46)";
            cursor-color = "rgb(245, 224, 220)";
            follow-last-tab = "true";
            font = "FiraCode Nerd Font Mono Medium 13";
            foreground = "rgb(205,214,244)";
            natural-copy-paste = false;
            palette = "rgb(69,71,90):rgb(243,139,168):rgb(166,227,161):rgb(249,226,175):rgb(137,180,250):rgb(245,194,231):rgb(148,226,213):rgb(186,194,222):rgb(88,91,112):rgb(243,139,168):rgb(166,227,161):rgb(249,226,175):rgb(137,180,250):rgb(245,194,231):rgb(148,226,213):rgb(166,173,200)";
            theme = "custom";
            unsafe-paste-alert = false;
          };

          "net/launchpad/plank/docks/dock1" = {
            alignment = "center";
            hide-mode = "window-dodge";
            icon-size = mkInt32 48;
            pinned-only = false;
            position = "left";
            theme = "Catppuccin-mocha";
          };

          "org/gnome/desktop/datetime" = {
            automatic-timezone = true;
          };

          "org/gnome/desktop/interface" = {
            clock-format = "24h";
            color-scheme = "prefer-dark";
            cursor-size = mkInt32 32;
            cursor-theme = "catppuccin-mocha-blue-cursors";
            document-font-name = "Work Sans 12";
            font-name = "Work Sans 12";
            gtk-theme = "catppuccin-mocha-blue-standard";
            gtk-enable-primary-paste = true;
            icon-theme = "Papirus-Dark";
            monospace-font-name = "FiraCode Nerd Font Mono Medium 13";
            text-scaling-factor = mkDouble 1.0;
          };

          "org/gnome/desktop/session" = {
            idle-delay = mkInt32 900;
          };

          "org/gnome/desktop/sound" = {
            theme-name = "elementary";
          };

          "org/gnome/desktop/wm/keybindings" = {
            switch-to-workspace-1 = [
              "<Control><Alt>1"
              "<Control><Alt>Home"
            ];
            switch-to-workspace-2 = [ "<Control><Alt>2" ];
            switch-to-workspace-3 = [ "<Control><Alt>3" ];
            switch-to-workspace-4 = [ "<Control><Alt>4" ];
            switch-to-workspace-5 = [ "<Control><Alt>5" ];
            switch-to-workspace-6 = [ "<Control><Alt>6" ];
            switch-to-workspace-7 = [ "<Control><Alt>7" ];
            switch-to-workspace-8 = [ "<Control><Alt>8" ];
            switch-to-workspace-down = [ "<Control><Alt>Down" ];
            switch-to-workspace-last = [ "<Control><Alt>End" ];
            switch-to-workspace-left = [ "<Control><Alt>Left" ];
            switch-to-workspace-right = [ "<Control><Alt>Right" ];
            switch-to-workspace-up = [ "<Control><Alt>Up" ];
            move-to-workspace-1 = [ "<Super><Alt>1" ];
            move-to-workspace-2 = [ "<Super><Alt>2" ];
            move-to-workspace-3 = [ "<Super><Alt>3" ];
            move-to-workspace-4 = [ "<Super><Alt>4" ];
            move-to-workspace-5 = [ "<Super><Alt>5" ];
            move-to-workspace-6 = [ "<Super><Alt>6" ];
            move-to-workspace-7 = [ "<Super><Alt>7" ];
            move-to-workspace-8 = [ "<Super><Alt>8" ];
            move-to-workspace-down = [ "<Super><Alt>Down" ];
            move-to-workspace-last = [ "<Super><Alt>End" ];
            move-to-workspace-left = [ "<Super><Alt>Left" ];
            move-to-workspace-right = [ "<Super><Alt>Right" ];
            move-to-workspace-up = [ "<Super><Alt>Up" ];
          };

          "org/gnome/desktop/wm/preferences" = {
            audible-bell = false;
            button-layout = "close,minimize,maximize";
            titlebar-font = "Work Sans Semi-Bold 12";
          };

          "org/gnome/GWeather" = {
            temperature-unit = "centigrade";
          };

          "org/gnome/mutter" = {
            workspaces-only-on-primary = false;
            dynamic-workspaces = false;
          };

          "org/gnome/mutter/keybindings" = {
            toggle-tiled-left = [ "<Super>Left" ];
            toggle-tiled-right = [ "<Super>Right" ];
          };

          "org/gnome/settings-daemon/plugins/media-keys" = {
            custom-keybindings = [
              "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
              "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
              "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
            ];
          };

          "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
            binding = "<Super>e";
            command = "io.elementary.files --new-window ~";
            name = "File Manager";
          };

          "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
            binding = "<Super>t";
            command = "io.elementary.terminal --new-window --working-directory=~";
            name = "Terminal";
          };

          "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
            binding = "<Primary><Alt>t";
            command = "io.elementary.terminal --new-window --working-directory=~";
            name = "Terminal";
          };

          "org/gnome/settings-daemon/plugins/power" = {
            power-button-action = "interactive";
            sleep-inactive-ac-timeout = mkInt32 0;
            sleep-inactive-ac-type = "nothing";
          };

          #"org/gnome/settings-daemon/plugins/xsettings" = {
          #  overrides = "{'Gtk/DialogsUseHeader': <0>, 'Gtk/ShellShowsAppMenu': <0>, 'Gtk/EnablePrimaryPaste': <0>, 'Gtk/DecorationLayout': <'close,minimize,maximize'>, 'Gtk/ShowUnicodeMenu': <0>}";
          #};

          "org/gtk/gtk4/Settings/FileChooser" = {
            clock-format = "24h";
          };

          "org/gtk/Settings/FileChooser" = {
            clock-format = "24h";
          };

          "org/pantheon/desktop/gala/appearance" = {
            button-layout = "close,minimize,maximize";
          };

          "org/pantheon/desktop/gala/behavior" = {
            dynamic-workspaces = false;
            move-fullscreened-workspace = false;
            move-maximized-workspace = false;
            overlay-action = "io.elementary.wingpanel --toggle-indicator=app-launcher";
          };

          "org/pantheon/desktop/gala/mask-corners" = {
            corner-radius = mkInt32 1;
            disable-on-fullscreen = true;
            enable = false;
            only-on-primary = false;
          };
        };
      }
    ];
    evince.enable = false;
    gnome-disks.enable = isInstall;
    seahorse.enable = isInstall;
  };

  security = {
    # Disable autoSuspend; my Pantheon session kept auto-suspending
    # - https://discourse.nixos.org/t/why-is-my-new-nixos-install-suspending/19500
    polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
          if (action.id == "org.freedesktop.login1.suspend" ||
              action.id == "org.freedesktop.login1.suspend-multiple-sessions" ||
              action.id == "org.freedesktop.login1.hibernate" ||
              action.id == "org.freedesktop.login1.hibernate-multiple-sessions")
          {
              return polkit.Result.NO;
          }
      });
    '';
  };

  services = {
    gnome = {
      gnome-online-accounts.enable = isInstall;
      gnome-keyring.enable = true;
    };
    gvfs.enable = true;
    xserver = {
      enable = true;
      displayManager = {
        # Disable autoSuspend; my Pantheon session kept auto-suspending
        # - https://discourse.nixos.org/t/why-is-my-new-nixos-install-suspending/19500
        gdm.autoSuspend = true;
        lightdm.enable = true;
        lightdm.greeters.pantheon.enable = true;
      };

      desktopManager = {
        pantheon = {
          enable = true;
          extraWingpanelIndicators = with pkgs; [
            wingpanel-indicator-ayatana
            monitor
          ];
        };
      };
    };
  };

  # App indicator
  # - https://github.com/NixOS/nixpkgs/issues/144045#issuecomment-992487775
  systemd.user.services.indicator-application-service = {
    description = "indicator-application-service";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.indicator-application-gtk3}/libexec/indicator-application/indicator-application-service";
    };
  };
}
