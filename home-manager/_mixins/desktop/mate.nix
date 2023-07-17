{ config, lib, pkgs, ... }:
with lib.hm.gvariant;
{
  dconf.settings = {
    "org/gnome/charmap" = {
      font = "Work Sans 22";
    };

    "org/gnome/desktop/interface" = {
      cursor-theme = "Yaru";
      document-font-name = "Work Sans 12";
      font-name = "Work Sans 12";
      gtk-theme = "Yaru-magenta-dark";
      icon-theme = "Yaru-magenta-dark";
      monospace-font-name = "FiraCode Nerd Font Medium 13";
    };

    "org/gnome/desktop/wm/preferences" = {
      button-layout = ":minimize,maximize,close";
      theme = "Yaru-dark";
      titlebar-font = "Work Sans Semi-Bold 12";
      titlebar-uses-system-font = false;
    };

    "org/gnome/evolution/mail" = {
      monospace-font = "FiraCode Nerd Font Medium 13";
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

    "org/mate/caja/list-view" = {
      default-zoom-level = "small";
    };

    "org/mate/caja/preferences" = {
      default-folder-view = "list-view";
    };

    "org/mate/dictionary" = {
      print-font = "Work Sans 12";
    };

    "org/mate/disk-usage-analyzer/ui" = {
      statusbar-visible = true;
    };

    "org/mate/desktop/applications/calculator" = {
      exec = "mate-calc";
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
      gtk-decoration-layout = ":minimize,maximize,close";
      gtk-theme = "Yaru-magenta-dark";
      gtk-color-scheme = "tooltip_fg_color:#ffffff\ntooltip_bg_color:#343434";
      icon-theme = "Yaru-magenta-dark";
      monospace-font-name = "FiraCode Nerd Font Medium 13";
    };

    "org/mate/desktop/peripherals/keyboard/kbd" = {
      options = [ "terminate\tterminate:ctrl_alt_bksp" "caps\tcaps:none" ];
    };

    "org/mate/desktop/peripherals/mouse" = {
      cursor-size = 32;
      cursor-theme = "Yaru";
    };

    "org/mate/desktop/peripherals/touchpad" = {
      disable-while-typing = true;
      tap-to-click = true;
      three-finger-click = 0;
      two-finger-click = 0;
    };

    "org/mate/desktop/session" = {
      idle-delay = 30;
    };

    "org/mate/desktop/sound" = {
      event-sounds = true;
      input-feedback-sounds = true;
      theme-name = "Yaru";
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
      button-layout = ":minimize,maximize,close";
      center-new-windows = false;
      compositing-manager = true;
      num-workspaces = 8;
      show-tab-border = false;
      theme = "Yaru-dark";
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
      switch-to-workspace-1 = "<Mod4>1";
      switch-to-workspace-2 = "<Mod4>2";
      switch-to-workspace-3 = "<Mod4>3";
      switch-to-workspace-4 = "<Mod4>4";
      switch-to-workspace-5 = "<Mod4>5";
      switch-to-workspace-6 = "<Mod4>6";
      switch-to-workspace-7 = "<Mod4>7";
      switch-to-workspace-8 = "<Mod4>8";
    };

    "org/mate/marco/keybinding-commands" = {
      command-1 = "mate-screensaver-command --lock";
      command-2 = "/bin/sh -c \"sleep 0.1; mate-screenshot --area\"";
      command-3 = "caja";
      command-4 = "mate-terminal --window";
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

    "org/mate/marco/workspace-names" = {
      name-1 = " Web ";
      name-2 = " Work ";
      name-3 = " Chat ";
      name-4 = " Code ";
      name-5 = " Virt ";
      name-6 = " Cast ";
      name-7 = " Fun ";
      name-8 = " Stuff ";
    };

    "org/mate/maximus" = {
      no-maximize = true;
      undecorate = false;
    };

    "org/mate/media-handling" = {
      autorun-x-content-start-app = [ "x-content/software" "x-content/video-bluray.xml" "x-content/video-dvd.xml" "x-content/video-hddvd.xml" "x-content/video-svcd.xml" "x-content/video-vcd.xml" ];
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
      color-scheme = "Yaru-dark";
      display-line-numbers = true;
      display-right-margin = true;
      display-overview-map = true;
      editor-font = "FiraCode Nerd Font Medium 13";
      highlight-current-line = true;
      insert-spaces = true;
      print-font-body-pango = "FiraCode Nerd Font Medium 10";
      print-font-header-pango = "Work Sans 11";
      print-font-numbers-pango = "Work Sans 8";
    };

    "org/mate/power-manager" = {
      button-power = "interactive";
      sleep-computer-ac = 0;
      sleep-display-ac = 3600;
    };

    "org/mate/screensaver" = {
      lock-delay = 1;
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
      cpu-color2 = "#CD5050";
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
      cpu-color3 = "#E67F7F";
      cpu-color30 = "#C4A000";
      cpu-color31 = "#EDD400";
      cpu-color4 = "#FFB4B4";
      cpu-color5 = "#9A5306";
      cpu-color6 = "#B47028";
      cpu-color7 = "#CD8F50";
      cpu-color8 = "#E6B37F";
      cpu-color9 = "#FFDBB5";
      show-tree = true;
      solaris-mode = false;
    };

    "org/mate/terminal/profile" = {
      allow-bold = false;
      use-system-font = true;
    };
  };

  gtk = {
    enable = true;
    cursorTheme = {
      name = "Yaru";
      package = pkgs.yaru-theme;
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
        gtk-application-prefer-dark-theme = 1;
      };
    };

    gtk4 = {
      extraConfig = {
        gtk-application-prefer-dark-theme = 1;
      };
    };

    iconTheme = {
      name = "Yaru-dark-magenta";
      package = pkgs.yaru-theme;
    };

    theme = {
      name = "Yaru-dark-magenta";
      package = pkgs.yaru-theme;
    };
  };

  home.pointerCursor = {
    name = "Yaru";
    package = pkgs.yaru-theme;
    size = 32;
    gtk.enable = true;
    x11.enable = true;
  };
}
