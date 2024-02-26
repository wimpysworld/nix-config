{ config, lib, pkgs, ... }:
with lib.hm.gvariant;
{
  imports = [
    ./celluloid.nix
    ./dconf-editor.nix
    ./gnome-sound-recorder.nix
    ./gnome-text-editor.nix
    ./tilix.nix
  ];
  dconf.settings = {
    "org/gnome/desktop/datetime" = {
      automatic-timezone = true;
    };

    "org/gnome/desktop/default/applications/terminal" = {
      exec = "${pkgs.tilix}/bin/tilix";
      exec-arg = "-e";
    };

    "org/gnome/desktop/input-sources" = {
      xkb-options = [ "grp:alt_shift_toggle" "caps:none" ];
    };

    "org/gnome/desktop/interface" = {
      clock-format = "24h";
      clock-show-weekday = true;
      color-scheme = "prefer-dark";
      cursor-size = 32;
      #cursor-theme = "elementary";
      document-font-name = "Work Sans 12";
      font-name = "Work Sans 12";
      #gtk-theme = "io.elementary.stylesheet.bubblegum";
      gtk-enable-primary-paste = true;
      #icon-theme = "elementary";
      monospace-font-name = "FiraCode Nerd Font Medium 13";
      text-scaling-factor = 1.0;
    };

    "org/gnome/desktop/peripherals/touchpad" = {
      tap-to-click = true;
    };

    "org/gnome/desktop/session" = {
      idle-delay = lib.hm.gvariant.mkUint32 900;
    };

    "org/gnome/desktop/sound" = {
      theme-name = "freedesktop";
    };

    "org/gnome/desktop/wm/keybindings" = {
      switch-to-workspace-left = [ "<Primary><Alt>Left" ];
      switch-to-workspace-right = [ "<Primary><Alt>Right" ];
    };

    "org/gnome/desktop/wm/preferences" = {
      audible-bell = false;
      button-layout = ":minimize,maximize,close";
      num-workspaces = 8;
      titlebar-font = "Work Sans Semi-Bold 12";
      workspace-names = [ "Web" "Work" "Chat" "Code" "Virt" "Cast" "Fun" "Stuff" ];
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

    "org/gnome/nautilus/preferences" = {
      default-folder-viewer="list-view";
    };

    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/"
      ];
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      binding = "<Super>e";
      command = "nautilus --new-windows ~/";
      name = "nautilus --new-windows ~/";
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
      binding = "<Super>t";
      command = "${pkgs.tilix}/bin/tilix";
      name = "tilix";
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
      binding = "<Primary><Alt>t";
      command = "${pkgs.tilix}/bin/tilix";
      name = "tilix";
    };

    # https://github.com/tom-james-watson/emote
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3" = {
      binding = "<Primary><Alt>e";
      command = "${pkgs.emote}/bin/emote";
      name = "emote";
    };

    "org/gnome/settings-daemon/plugins/power" = {
      power-button-action = "interactive";
      sleep-inactive-ac-timeout = 0;
      sleep-inactive-ac-type = "nothing";
    };

    "org/gnome/shell" = {
      disabled-extensions = [];
      enabled-extensions = [ "appindicatorsupport@rgcjonas.gmail.com" "dash-to-dock@micxgx.gmail.com" "workspace-indicator@gnome-shell-extensions.gcampax.github.com" "auto-move-windows@gnome-shell-extensions.gcampax.github.com" "autohide-battery@sitnik.ru" "just-perfection-desktop@just-perfection" "waylandorx11@injcristianrojas.github.com" "wifiqrcode@glerro.pm.me" "wireless-hid@chlumskyvaclav.gmail.com" "logomenu@aryan_k" "status-area-horizontal-spacing@mathematical.coffee.gmail.com" ];
    };

    "org/gnome/shell/extensions/auto-move-windows" = {
      application-list = [ "brave-browser.desktop:1" "Wavebox.desktop:2" "discord.desktop:2" "org.telegram.desktop.desktop:3" "nheko.desktop:3" "code.desktop:4" "GitKraken.desktop:4" "com.obsproject.Studio.desktop:6" ];
    };

    "org/gnome/shell/extensions/dash-to-dock" = {
      disable-overview-on-startup = true;
      dock-position = "LEFT";
      hot-keys = false;
      show-trash = false;
    };

    "org/gnome/shell/extensions/just-perfection" = {
      startup-status = 0;
      window-demands-attention-focus = true;
    };

    "org/gnome/shell/extensions/Logo-menu" = {
      menu-button-icon-image = 23;
      menu-button-terminal = "${pkgs.tilix}/bin/tilix";
      show-activities-button = true;
      symbolic-icon = true;
    };

    "org/gtk/gtk4/Settings/FileChooser" = {
      clock-format = "24h";
    };

    "org/gtk/Settings/FileChooser" = {
      clock-format = "24h";
    };
  };

  gtk = {
    enable = true;
    #cursorTheme = {
      #name = "elementary";
      #package = pkgs.pantheon.elementary-icon-theme;
    #  size = 32;
    #};

    font = {
      name = "Work Sans 12";
      package = pkgs.work-sans;
    };

    gtk2 = {
      configLocation = "${config.xdg.configHome}/gtk-2.0/gtkrc";
      extraConfig = ''
        gtk-application-prefer-dark-theme = 1
        gtk-decoration-layout = ":minimize,maximize,close"
        gtk-enable-primary-paste = true
      '';
    };

    gtk3 = {
      extraConfig = {
        gtk-application-prefer-dark-theme = 1;
        gtk-decoration-layout = ":minimize,maximize,close";
        gtk-enable-primary-paste = true;
      };
    };

    gtk4 = {
      extraConfig = {
        gtk-application-prefer-dark-theme = 1;
        gtk-decoration-layout = ":minimize,maximize,close";
        gtk-enable-primary-paste = true;
      };
    };

    #iconTheme = {
    #  name = "elementary";
    #  package = pkgs.pantheon.elementary-icon-theme;
    #};

    #theme = {
    #  name = "io.elementary.stylesheet.bubblegum";
    #  package = pkgs.pantheon.elementary-gtk-theme;
    #};
  };

  #home.pointerCursor = {
    #package = pkgs.pantheon.elementary-icon-theme;
    #name = "elementary";
    #size = 32;
  #  gtk.enable = true;
  #  x11.enable = true;
  #};

  xdg = {
    desktopEntries = {
      # The usbimager icon path is hardcoded, so override the desktop file
      usbimager = {
        name = "USBImager";
        exec = "${pkgs.usbimager}/bin/usbimager";
        terminal = false;
        icon = "usbimager";
        type = "Application";
        categories = [ "System" "Application" ];
      };
    };
  };
}
