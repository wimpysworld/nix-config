{
  config,
  desktop,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux isDarwin;
in
{
  # Enable the Catppuccin theme
  catppuccin = {
    kitty.enable = config.programs.kitty.enable;
  };

  # User specific dconf terminal-related settings
  dconf.settings = with lib.hm.gvariant; {
    "org/gnome/settings-daemon/plugins/media-keys" = lib.mkIf (desktop == "pantheon") {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
      ];
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" =
      lib.mkIf (desktop == "pantheon")
        {
          binding = "<Super>t";
          name = "Terminal";
          command = "kitty";
        };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" =
      lib.mkIf (desktop == "pantheon")
        {
          binding = "<Primary><Alt>t";
          name = "Terminal";
          command = "kitty";
        };

    "org/gnome/desktop/default/applications/terminal" = lib.mkIf (desktop == "pantheon") {
      exec = "kitty";
      exec-arg = "-e";
    };
  };

  programs = {
    kitty = {
      enable = true;
      font = {
        name = "FiraCode Nerd Font Mono";
        size = 16;
      };
      settings = {
        cursor_blink_interval = 0.75;
        cursor_shape = "block";
        cursor_shape_unfocused = "hollow";
        cursor_stop_blinking_after = 0;
        hide_window_decorations = if config.wayland.windowManager.hyprland.enable then true else false;
        scrollback_indicator_opacity = 0.50;
        scrollback_lines = 65536;
        shell = lib.mkIf isDarwin "${pkgs.fish}/bin/fish --interactive";
        draw_minimal_borders = "yes";
        window_border_width = "0pt";
        window_margin_width = 0;
        single_window_margin_width = 0;
        sync_to_monitor = "yes";
        term = "xterm-256color";
        # Mouse
        copy_on_select = true;
        mouse_hide_wait = 0;
        strip_trailing_spaces = "smart";
        wheel_scroll_multiplier = 2;
        # Bell
        enable_audio_bell = "no";
        visual_bell = 0.25;
      };
      shellIntegration = {
        enableBashIntegration = false;
        enableFishIntegration = false;
        enableZshIntegration = false;
      };
      extraConfig = ''
        cursor_trail 500
        cursor_trail_decay 0.175 0.425
        cursor_trail_start_threshold 2
      '';
    };
    fuzzel = lib.mkIf config.programs.fuzzel.enable {
      settings.main.terminal = "kitty";
    };
  };

  wayland.windowManager.hyprland = lib.mkIf config.wayland.windowManager.hyprland.enable {
    settings = {
      bind = [
        "$mod, T, exec, kitty"
      ];
    };
  };

  xresources.properties = {
    "*background" = "#1E1E2E";
    "*foreground" = "#CDD6F4";
    # black
    "*color0" = "#45475A";
    "*color8" = "#585B70";
    # red
    "*color1" = "#F38BA8";
    "*color9" = "#F38BA8";
    # green
    "*color2" = "#A6E3A1";
    "*color10" = "#A6E3A1";
    # yellow
    "*color3" = "#F9E2AF";
    "*color11" = "#F9E2AF";
    # blue
    "*color4" = "#89B4FA";
    "*color12" = "#89B4FA";
    #magenta
    "*color5" = "#F5C2E7";
    "*color13" = "#F5C2E7";
    #cyan
    "*color6" = "#94E2D5";
    "*color14" = "#94E2D5";
    #white
    "*color7" = "#BAC2DE";
    "*color15" = "#A6ADC8";

    # Xterm Appearance
    "XTerm*background" = "#1E1E2E";
    "XTerm*foreground" = "#CDD6F4";
    "XTerm*letterSpace" = 0;
    "XTerm*lineSpace" = 0;
    "XTerm*geometry" = "132x50";
    "XTerm.termName" = "xterm-256color";
    "XTerm*internalBorder" = 2;
    "XTerm*faceName" = "FiraCode Nerd Font Mono:size=14:style=Medium:antialias=true";
    "XTerm*boldFont" = "FiraCode Nerd Font Mono:size=14:style=Bold:antialias=true";
    "XTerm*boldColors" = true;
    "XTerm*cursorBlink" = true;
    "XTerm*cursorUnderline" = false;
    "XTerm*saveline" = 2048;
    "XTerm*scrollBar" = false;
    "XTerm*scrollBar_right" = false;
    "XTerm*urgentOnBell" = true;
    "XTerm*depth" = 24;
    "XTerm*utf8" = true;
    "XTerm*locale" = false;
    "XTerm.vt100.metaSendsEscape" = true;
  };
}
