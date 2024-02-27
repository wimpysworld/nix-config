{ config, lib, hostname, pkgs, ... }:
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

    "org/gnome/settings-daemon/plugins/power" = {
      power-button-action = "interactive";
      sleep-inactive-ac-timeout = 0;
      sleep-inactive-ac-type = "nothing";
    };

    "org/gnome/shell" = {
      disabled-extensions = [];
      enabled-extensions = [ "appindicatorsupport@rgcjonas.gmail.com" "dash-to-dock@micxgx.gmail.com" "auto-move-windows@gnome-shell-extensions.gcampax.github.com" "autohide-battery@sitnik.ru" "just-perfection-desktop@just-perfection" "wifiqrcode@glerro.pm.me" "logomenu@aryan_k" "status-area-horizontal-spacing@mathematical.coffee.gmail.com" "emoji-copy@felipeftn" "freon@UshakovVasilii_Github.yahoo.com" "upower-battery@codilia.com" "batime@martin.zurowietz.de" "workspace-switcher-manager@G-dH.github.com" "hide-workspace-thumbnails@dylanmc.ca" "Vitals@CoreCoding.com"]
      ++ lib.optionals (hostname == "tanis" || hostname == "sidious") [ "thinkpad-battery-threshold@marcosdalvarez.org" ];
    };

    "org/gnome/shell/extensions/auto-move-windows" = {
      application-list = [ "brave-browser.desktop:1" "Wavebox.desktop:2" "discord.desktop:2" "org.telegram.desktop.desktop:3" "nheko.desktop:3" "code.desktop:4" "GitKraken.desktop:4" "com.obsproject.Studio.desktop:6" ];
    };

    "org/gnome/shell/extensions/emoji-copy" = {
      always-show = false;
      emoji-keybind = [ "<Primary><Alt>e" ];
    };

    "org/gnome/shell/extensions/dash-to-dock" = {
      click-action = "skip";
      disable-overview-on-startup = true;
      dock-position = "LEFT";
      hot-keys = false;
      scroll-action = "cycle-windows";
      show-trash = false;
    };

    "org/gnome/shell/extensions/just-perfection" = {
      startup-status = 0;
      window-demands-attention-focus = true;
    };

    "org/gnome/shell/extensions/Logo-menu" = {
      menu-button-icon-image = 23;
      menu-button-system-monitor = "${pkgs.gnome-usage}/bin/gnome-usage";
      menu-button-terminal = "${pkgs.tilix}/bin/tilix";
      show-activities-button = true;
      symbolic-icon = true;
    };

    "org/gnome/shell/extensions/vitals" = {
      alphabetize = false;
      fixed-widths = true;
      include-static-info = false;
      menu-centered = true;
      monitor-cmd = "${pkgs.gnome-usage}/bin/gnome-usage";
      network-speed-format = 1;
      show-temperature = false;
      show-fan = false;
      update-time = 2;
      use-higher-precision = false;
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
      '';
    };

    gtk3 = {
      extraConfig = {
        gtk-application-prefer-dark-theme = 1;
        gtk-decoration-layout = ":minimize,maximize,close";
      };
    };

    gtk4 = {
      extraConfig = {
        gtk-application-prefer-dark-theme = 1;
        gtk-decoration-layout = ":minimize,maximize,close";
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

  services = {
    gpg-agent.pinentryFlavor = lib.mkForce "gnome3";
    # https://nixos.wiki/wiki/Bluetooth#Using_Bluetooth_headsets_with_PulseAudio
    mpris-proxy.enable = true;
  };

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
