{ config, lib, pkgs, hostname,... }:
let
  isInstall = if (builtins.substring 0 4 hostname != "iso-") then true else false;
  isISO = !isInstall;
  isThinkpad = if (hostname == "tanis" || hostname == "sidious") then true else false;
in
{
  environment = {
    gnome.excludePackages = (with pkgs; [
      baobab
      blackbox-terminal
      gnome.geary
      gnome.gnome-music
      gnome.gnome-system-monitor
      gnome.epiphany
      gnome.totem
    ] ++ lib.optionals (isISO) [
      # Don't install these on the ISO
      gnome.gnome-backgrounds
      gnome.gnome-calendar
      gnome.gnome-characters
      gnome.gnome-clocks
      gnome.gnome-contacts
      gnome.gnome-font-viewer
      gnome.gnome-logs
      gnome.gnome-maps
      gnome.simple-scan
      gnome.gnome-weather
      gnome.yelp
      gnome-connections
      gnome-tour
      gnome-user-docs
      loupe
      snapshot
    ]);

    systemPackages = (with pkgs; [
      gnome-usage
      gnomeExtensions.appindicator
      gnomeExtensions.autohide-battery
      gnomeExtensions.dash-to-dock
      gnomeExtensions.emoji-copy
      gnomeExtensions.favourites-in-appgrid
      gnomeExtensions.just-perfection
      gnomeExtensions.logo-menu
      gnomeExtensions.tiling-assistant
      gnomeExtensions.wireless-hid
      gnomeExtensions.vitals
      gnomeExtensions.wifi-qrcode
      unstable.gnomeExtensions.workspace-switcher-manager
    ] ++ lib.optionals (isInstall) [
      eyedropper
      gnome.gnome-tweaks
      gnome.simple-scan
      gnomeExtensions.freon
    ] ++ lib.optionals (isThinkpad) [
      gnomeExtensions.thinkpad-battery-threshold
    ]);
  };

  programs = {
    calls.enable = false;
    # https://github.com/NixOS/nixpkgs/pull/234615
    # https://github.com/Electrostasy/dots/blob/master/profiles/system/gnome/default.nix#L160
    # https://discourse.nixos.org/t/configuration-of-gnome-extensions/33337
    dconf.profiles.user.databases = [{
      settings = with lib.gvariant; {
        "com/raggesilver/BlackBox" = {
          cursor-blink-mode = mkUint32 1;
          cursor-shape = mkUint32 0;
          easy-copy-paste = true;
          floating-controls = true;
          floating-controls-hover-area = mkUint32 20;
          font = "FiraCode Nerd Font Mono Medium 12";
          pretty = true;
          remember-window-size = true;
          scrollback-lines = mkUint32 10240;
          theme-dark = "Adwaita Dark";
          window-height = mkUint32 1150;
          window-width = mkUint32 1450;
        };

        "org/gnome/desktop/datetime" = {
          automatic-timezone = true;
        };

        "org/gnome/desktop/default/applications/terminal" = {
          exec = "blackbox";
          exec-arg = "-c";
        };

        "org/gnome/desktop/interface" = {
          clock-format = "24h";
          clock-show-weekday = true;
          color-scheme = "prefer-dark";
          cursor-size = mkInt32 32;
          cursor-theme = "Adwaita";
          document-font-name = "Work Sans 12";
          enable-hot-corners = false;
          font-name = "Work Sans 12";
          gtk-theme = "adw-gtk3-dark";
          icon-theme = "Adwaita";
          monospace-font-name = "FiraCode Nerd Font Medium 13";
          show-battery-percentage = true;
          text-scaling-factor = mkDouble 1.0;
        };

        "org/gnome/desktop/peripherals/touchpad" = {
          tap-to-click = true;
        };

        "org/gnome/desktop/session" = {
          idle-delay = mkInt32 900;
        };

        "org/gnome/desktop/sound" = {
          theme-name = "freedesktop";
        };

        "org/gnome/desktop/wm/keybindings" = {
          switch-to-workspace-1 = [ "<Control><Alt>1" "<Control><Alt>Home" "<Super>Home" ];
          switch-to-workspace-2 = [ "<Control><Alt>2" ];
          switch-to-workspace-3 = [ "<Control><Alt>3" ];
          switch-to-workspace-4 = [ "<Control><Alt>4" ];
          switch-to-workspace-5 = [ "<Control><Alt>5" ];
          switch-to-workspace-6 = [ "<Control><Alt>6" ];
          switch-to-workspace-7 = [ "<Control><Alt>7" ];
          switch-to-workspace-8 = [ "<Control><Alt>8" ];
          switch-to-workspace-down = [ "<Control><Alt>Down" ];
          switch-to-workspace-last = [ "<Control><Alt>End" "<Super>End" ];
          switch-to-workspace-left = [ "<Control><Alt>Left" "<Super>Page_Up"];
          switch-to-workspace-right = [ "<Control><Alt>Right" "<Super>Page_Down"];
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
          move-to-workspace-left = [ "<Super><Alt>Left" "<Super><Shift>Page_Up"];
          move-to-workspace-right = [ "<Super><Alt>Right" "<Super><Shift>Page_Down" ];
          move-to-workspace-up = [ "<Super><Alt>Up" ];
          # Disable maximise/unmaximise because tiling-assistant extension handles it
          maximize = mkEmptyArray type.string;
          unmaximize = mkEmptyArray type.string;
        };

        "org/gnome/desktop/wm/preferences" = {
          audible-bell = false;
          button-layout = ":minimize,maximize,close";
          titlebar-font = "Work Sans Semi-Bold 12";
        };

        "org/gnome/GWeather" = {
          temperature-unit = "centigrade";
        };

        "org/gnome/mutter" = {
          dynamic-workspaces = false;
          # Disable Mutter edge-tiling because tiling-assistant extension handles it
          edge-tiling = false;
          workspaces-only-on-primary = false;
        };

        "org/gnome/mutter/keybindings" = {
          # Disable Mutter toggle-tiled because tiling-assistant extension handles it
          toggle-tiled-left = mkEmptyArray type.string;
          toggle-tiled-right = mkEmptyArray type.string;
        };

        "org/gnome/nautilus/preferences" = {
          default-folder-viewer="list-view";
        };

        "org/gnome/settings-daemon/plugins/media-keys" = {
          home = "[ <Super>e ]";
          custom-keybindings = [
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
          ];
        };

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
          binding = "<Super>t";
          command = "blackbox";
          name = "Terminal";
        };

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
          binding = "<Primary><Alt>t";
          command = "blackbox";
          name = "Terminal";
        };

        "org/gnome/settings-daemon/plugins/power" = {
          power-button-action = "interactive";
          sleep-inactive-ac-timeout = mkInt32 0;
          sleep-inactive-ac-type = "nothing";
        };

        "org/gnome/shell" = {
          enabled-extensions = [
            "appindicatorsupport@rgcjonas.gmail.com"
            "autohide-battery@sitnik.ru"
            "auto-move-windows@gnome-shell-extensions.gcampax.github.com"
            "dash-to-dock@micxgx.gmail.com"
            "emoji-copy@felipeftn"
            "just-perfection-desktop@just-perfection"
            "logomenu@aryan_k"
            "tiling-assistant@leleat-on-github"
            "Vitals@CoreCoding.com"
            "wireless-hid@chlumskyvaclav.gmail.com"
            "wifiqrcode@glerro.pm.me"
            "workspace-switcher-manager@G-dH.github.com"
          ]
          ++ lib.optionals (isInstall) [ "freon@UshakovVasilii_Github.yahoo.com" ]
          ++ lib.optionals (isThinkpad) [ "thinkpad-battery-threshold@marcosdalvarez.org" ];
        };

        "org/gnome/shell/extensions/dash-to-dock" = {
          click-action = "skip";
          disable-overview-on-startup = true;
          dock-position = "LEFT";
          hot-keys = true;
          scroll-action = "cycle-windows";
          show-trash = false;
        };

        "org/gnome/shell/extensions/emoji-copy" = {
          always-show = false;
          emoji-keybind = [ "<Primary><Alt>e" ];
        };

        "org/gnome/shell/extensions/just-perfection" = {
          panel-button-padding-size = mkInt32 5;
          panel-indicator-padding-size = mkInt32 3;
          startup-status = mkInt32 0;
          window-demands-attention-focus = true;
          workspaces-in-app-grid = false;
        };

        "org/gnome/shell/extensions/Logo-menu" = {
          menu-button-icon-image = mkInt32 23;
          menu-button-system-monitor = "gnome-usage";
          menu-button-terminal = "blackbox";
          show-activities-button = true;
          symbolic-icon = true;
        };

        "org/gnome/shell/extensions/thinkpad-battery-threshold" = {
          color-mode = false;
        };

        "org/gnome/shell/extensions/tiling-assistant" = {
          enable-advanced-experimental-features = true;
          single-screen-gap = mkInt32 10;
          window-gap = mkInt32 10;
          maximize-with-gap = true;
        };

        "org/gnome/shell/extensions/vitals" = {
          alphabetize = false;
          fixed-widths = true;
          include-static-info = false;
          menu-centered = true;
          monitor-cmd = "gnome-usage";
          network-speed-format = mkInt32 1;
          show-fan = false;
          show-temperature = false;
          show-voltage = false;
          update-time = mkInt32 2;
          use-higher-precision = false;
        };

        "org/gnome/shell/extensions/wireless-hid" = {
          panel-box-index = mkInt32 4;
        };

        "org/gnome/shell/extensions/workspace-switcher-manager" = {
          active-show-ws-name = true;
          active-show-app-name = false;
          inactive-show-ws-name = true;
          inactive-show-app-name = false;
        };

        "org/gtk/gtk4/Settings/FileChooser" = {
          clock-format = "24h";
        };

        "org/gtk/gtk4/settings/file-chooser" = {
          show-hidden = false;
          show-size-column = true;
          show-type-column = true;
          sort-column = "name";
          sort-directories-first = true;
          sort-order = "ascending";
          type-format = "category";
          view-type = "list";
        };

        "org/gtk/Settings/FileChooser" = {
          clock-format = "24h";
        };

        "org/gtk/settings/file-chooser" = {
          show-hidden = false;
          show-size-column = true;
          show-type-column = true;
          sort-column = "name";
          sort-directories-first = true;
          sort-order = "ascending";
          type-format = "category";
        };
      };
    }];
    evince.enable = isInstall;
    file-roller.enable = isInstall;
    geary.enable = false;
    gnome-disks.enable = isInstall;
    gnome-terminal.enable = false;
    seahorse.enable = isInstall;
  };

  qt = {
    enable = true;
    platformTheme = "gnome";
    style = "adwaita-dark";
  };

  # Allow login/authentication with fingerprint or password
  # - https://github.com/NixOS/nixpkgs/issues/171136
  # - https://discourse.nixos.org/t/fingerprint-auth-gnome-gdm-wont-allow-typing-password/35295
  security.pam.services.login.fprintAuth = false;
  security.pam.services.gdm-fingerprint = lib.mkIf (config.services.fprintd.enable) {
    text = ''
      auth       required                    pam_shells.so
      auth       requisite                   pam_nologin.so
      auth       requisite                   pam_faillock.so      preauth
      auth       required                    ${pkgs.fprintd}/lib/security/pam_fprintd.so
      auth       optional                    pam_permit.so
      auth       required                    pam_env.so
      auth       [success=ok default=1]      ${pkgs.gnome.gdm}/lib/security/pam_gdm.so
      auth       optional                    ${pkgs.gnome.gnome-keyring}/lib/security/pam_gnome_keyring.so

      account    include                     login

      password   required                    pam_deny.so

      session    include                     login
      session    optional                    ${pkgs.gnome.gnome-keyring}/lib/security/pam_gnome_keyring.so auto_start
    '';
  };
  security.pam.services.gdm.enableGnomeKeyring = true;

  services = {
    gnome = {
      evolution-data-server.enable = lib.mkForce isInstall;
      games.enable = false;
      gnome-browser-connector.enable = isInstall;
      gnome-online-accounts.enable = isInstall;
      tracker.enable = isInstall;
      tracker-miners.enable = isInstall;
    };
    udev.packages = with pkgs; [ gnome.gnome-settings-daemon ];
    xserver = {
      enable = true;
      displayManager = {
        gdm = {
          enable = true;
          autoSuspend = false;
        };
      };
      desktopManager.gnome.enable = true;
    };
  };

  xdg.portal = {
    config = {
      gnome = {
        default = [
          "gnome"
          "gtk"
        ];
        "org.freedesktop.impl.portal.Secret" = [
          "gnome-keyring"
        ];
      };
    };
  };
}
