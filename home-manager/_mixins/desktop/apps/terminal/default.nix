{
  catppuccinPalette,
  config,
  desktop,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux isDarwin;
  # Helper function to get color as hex string
  getColor = colorName: catppuccinPalette.getColor colorName;
in
{
  # Enable the Catppuccin theme
  catppuccin = {
    kitty.enable = config.programs.kitty.enable;
  };

  # User specific dconf terminal-related settings
  dconf.settings = with lib.hm.gvariant; {
    "com/github/stunkymonkey/nautilus-open-any-terminal" = {
      terminal = "kitty";
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

  wayland.windowManager = {
    hyprland = lib.mkIf config.wayland.windowManager.hyprland.enable {
      settings = {
        bind = [
          "$mod, T, exec, kitty"
        ];
      };
    };
    wayfire = lib.mkIf config.wayland.windowManager.wayfire.enable {
      settings = {
        command = {
          # Super+T launches a terminal
          binding_terminal = "<super> KEY_T";
          command_terminal = "${lib.getExe pkgs.kitty}";
        };
      };
    };
  };

  xresources.properties = {
    "*background" = getColor "base";
    "*foreground" = getColor "text";
    # black
    "*color0" = getColor "surface1";
    "*color8" = getColor "surface2";
    # red
    "*color1" = getColor "red";
    "*color9" = getColor "red";
    # green
    "*color2" = getColor "green";
    "*color10" = getColor "green";
    # yellow
    "*color3" = getColor "yellow";
    "*color11" = getColor "yellow";
    # blue
    "*color4" = getColor "blue";
    "*color12" = getColor "blue";
    #magenta
    "*color5" = getColor "pink";
    "*color13" = getColor "pink";
    #cyan
    "*color6" = getColor "teal";
    "*color14" = getColor "teal";
    #white
    "*color7" = getColor "subtext1";
    "*color15" = getColor "subtext0";

    # Xterm Appearance
    "XTerm*background" = getColor "base";
    "XTerm*foreground" = getColor "text";
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
