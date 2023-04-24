{ config, lib, pkgs, ... }:
with lib.hm.gvariant;
{
  dconf.settings = {
    "desktop/ibus/panel" = {
      show-icon-on-systray = false;
      use-custom-font = true;
      custom-font = "Work Sans 10";
    };

    "desktop/ibus/panel/emoji" = {
      font = "JoyPixels 16";
    };

    "io/elementary/code/saved-state" = {
      outline-visible = true;
    };

    "io/elementary/code/settings" = {
      strip-trailing-on-save = true;
      show-mini-map = true;
      show-right-margin = true;
      style-scheme = "Yaru-dark";
      prefer-dark-style = true;
    };

    "io/elementary/desktop/agent-geoclue2" = {
      location-enabled = true;
    };

    "io/elementary/desktop/wingpanel/datetime" = {
      clock-format = "24h";
    };

    "io/elementary/desktop/wingpanel/sound" = {
      max-volume = 100.0;
    };

    "io/elementary/files/preferences" = {
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
      background = "rgb(18,18,20)";
      cursor-color = "rgb(255,182,56)";
      follow-last-tab = "true";
      font = "FiraCode Nerd Font Medium 13";
      foreground = "rgb(200,200,200)";
      natural-copy-paste = false;
      palette = "rgb(20,20,23):rgb(214,43,43):rgb(65,221,117):rgb(255,182,56):rgb(40,169,255):rgb(230,109,255):rgb(20,229,211):rgb(200,200,200):rgb(67,67,69):rgb(222,86,86):rgb(161,238,187):rgb(255,219,156):rgb(148,212,255):rgb(243,182,255):rgb(161,245,238):rgb(233,233,233)";
      theme = "custom";
      unsafe-paste-alert = false;
    };

    #"org/gnome/desktop/background" = {
    #  picture-uri = "file:///home/martin/.local/share/backgrounds/2023-02-09-20-47-36-DeterminateColorway-2560x1440.png";
    #};

    "org/gnome/desktop/default/applications/terminal" = {
      exec = "tilix";
      exec-arg = "-e";
    };

    "org/gnome/desktop/datetime" = {
      automatic-timezone = true;
    };

    "org/gnome/desktop/input-sources" = {
      xkb-options = [ "grp:alt_shift_toggle" "caps:none" ];
    };

    "org/gnome/desktop/interface" = {
      clock-format = "24h";
      color-scheme = "prefer-dark";
      cursor-size = 32;
      cursor-theme = "elementary";
      document-font-name = "Work Sans 12";
      font-name = "Work Sans 12";
      gtk-theme = "io.elementary.stylesheet.bubblegum";
      gtk-enable-primary-paste = true;
      icon-theme = "elementary";
      monospace-font-name = "FiraCode Nerd Font Medium 13";
      text-scaling-factor = 1.0;
    };

    "org/gnome/desktop/session" = {
      idle-delay = lib.hm.gvariant.mkUint32 7200;
    };

    "org/gnome/desktop/sound" = {
      theme-name = "elementary";
    };

    "org/gnome/desktop/wm/keybindings" = {
      switch-to-workspace-left = [ "<Primary><Alt>Left" ];
      switch-to-workspace-right = [ "<Primary><Alt>Right" ];
    };

    "org/gnome/desktop/wm/preferences" = {
      button-layout = ":minimize,maximize,close";
      audible-bell = false;
      titlebar-font = "Work Sans Semi-Bold 12";
    };

    "org/gnome/GWeather" = {
      temperature-unit = "centigrade";
    };

    "org/gnome/mutter/keybindings" = {
      toggle-tiled-left = [ "<Super>Left" ];
      toggle-tiled-right = [ "<Super>Right" ];
    };

    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [ "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/" "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/" "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/" ];
      terminal = [ "" ];
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      binding = "<Super>t";
      command = "tilix";
      name = "tilix";
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
      binding = "<Primary><Alt>t";
      command = "tilix";
      name = "tilix";
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
      binding = "<Super>e";
      command = "io.elementary.files -n ~/";
      name = "io.elementary.files -n ~/";
    };

    "org/gnome/settings-daemon/plugins/power" = {
      power-button-action = "interactive";
      sleep-inactive-ac-timeout = 0;
      sleep-inactive-ac-type = "nothing";
    };

    #"org/gnome/settings-daemon/plugins/xsettings" = {
    #  overrides = "{\'Gtk/DialogsUseHeader\': <0>, \'Gtk/ShellShowsAppMenu\': <0>, \'Gtk/EnablePrimaryPaste\': <1>, \'Gtk/DecorationLayout\': <\':minimize,maximize,close,menu\'>, \'Gtk/ShowUnicodeMenu\': <0>}";
    #};

    "org/gtk/gtk4/Settings/FileChooser" = {
      clock-format = "24h";
    };

    "org/gtk/Settings/FileChooser" = {
      clock-format = "24h";
    };

    "org/pantheon/desktop/gala/appearance" = {
      button-layout = ":minimize,maximize,close";
    };

    "org/pantheon/desktop/gala/behavior" = {
      overlay-action = "io.elementary.wingpanel --toggle-indicator=app-launcher";
    };

    "org/pantheon/desktop/gala/mask-corners" = {
      enable = false;
    };
  };

  gtk = {
    enable = true;
    cursorTheme = {
      name = "elementary";
      package = pkgs.pantheon.elementary-icon-theme;
      size = 32;
    };

    font = {
      name = "Work Sans 12";
      package = pkgs.work-sans;
    };

    gtk2 = {
      configLocation = "${config.xdg.configHome}/gtk-2.0/gtkrc";
      extraConfig = ''
        gtk-application-prefer-dark-theme=1
      '';
    };

    gtk3 = {
      extraConfig = {
        gtk-application-prefer-dark-theme=1;
      };
    };

    gtk4 = {
      extraConfig = {
        gtk-application-prefer-dark-theme=1;
      };
    };

    iconTheme = {
      name = "elementary";
      package = pkgs.pantheon.elementary-icon-theme;
    };

    theme = {
      name = "io.elementary.stylesheet.bubblegum";
      package = pkgs.pantheon.elementary-gtk-theme;
    };
  };

  home.pointerCursor = {
    package = pkgs.pantheon.elementary-icon-theme;
    name = "elementary";
    size = 32;
    gtk.enable = true;
    x11.enable = true;
  };

  home.file = {
    "${config.xdg.configHome}/autostart/enable-appcenter.desktop".text = "
[Desktop Entry]
Name=Enable AppCenter
Comment=Enable AppCenter
Type=Application
Exec=flatpak remote-add --user --if-not-exists appcenter https://flatpak.elementary.io/repo.flatpakrepo
Categories=
Terminal=false
NoDisplay=true
StartupNotify=false";
  };

  home.file = {
    "${config.xdg.configHome}/autostart/ibus-daemon.desktop".text = "
[Desktop Entry]
Name=IBus Daemon
Comment=IBus Daemon
Type=Application
Exec=ibus-daemon --daemonize --desktop=pantheon
Categories=
Terminal=false
NoDisplay=true
StartupNotify=false";
  };
}
