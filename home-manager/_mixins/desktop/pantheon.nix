{ config, lib, pkgs, ... }:
with lib.hm.gvariant;
{
  dconf.settings = {
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
    };

    #"org/gnome/desktop/background" = {
    #  picture-uri = "file:///home/martin/.local/share/backgrounds/2023-02-09-20-47-36-DeterminateColorway-2560x1440.png";
    #};

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
      text-scaling-factor = 1.25;
    };

    "org/gnome/desktop/session" = {
      idle-delay = "uint32 7200";
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
      custom-keybindings = [ "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/" "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/" ];
      terminal = [ "<Primary><Alt>t" ];
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      binding = "<Super>t";
      command = "io.elementary.terminal -n";
      name = "io.elementary.terminal -n";
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
      binding = "<Super>e";
      command = "io.elementary.files -n ~/";
      name = "io.elementary.files -n ~/";
    };

    "org/gnome/settings-daemon/plugins/power" = {
      power-button-action = "interactive";
      sleep-inactive-ac-timeout = 0;
      sleep-inactive-ac-type = "nothing";
    };

    "org/gtk/gtk4/Settings/FileChooser" = {
      clock-format = "24h";
    };

    "org/gtk/Settings/FileChooser" = {
      clock-format = "24h";
    };

    "org/pantheon/desktop/gala/appearance" = {
      button-layout = ":minimize,maximize,close";
    };

    "org/gnome/settings-daemon/plugins/xsettings" = {
      overrides = "{'Gtk/DialogsUseHeader': <0>, 'Gtk/ShellShowsAppMenu': <0>, 'Gtk/EnablePrimaryPaste': <1>, 'Gtk/DecorationLayout': <':minimize,maximize,close,menu'>, 'Gtk/ShowUnicodeMenu': <0>}";
    };

    "org/pantheon/desktop/gala/behavior" = {
      overlay-action = "io.elementary.wingpanel --toggle-indicator=app-launcher";
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

