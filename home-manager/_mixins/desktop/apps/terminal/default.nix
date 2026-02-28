{
  catppuccinPalette,
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  # Helper function to get color as hex string
  getColor = colorName: catppuccinPalette.getColor colorName;
  hideWindowDecorations =
    if config.wayland.windowManager.wayfire.enable then
      false
    else if config.wayland.windowManager.hyprland.enable then
      true
    else
      false;
in
{
  # Enable the Catppuccin theme
  catppuccin = {
    kitty.enable = config.programs.kitty.enable;
  };

  # User specific dconf terminal-related settings. Nautilus is only installed
  # on workstations, so gate this setting accordingly.
  dconf = lib.mkIf (host.is.linux && host.is.workstation) {
    settings = with lib.hm.gvariant; {
      "com/github/stunkymonkey/nautilus-open-any-terminal" = {
        terminal = "${lib.getExe config.programs.kitty.package}";
      };
    };
  };

  programs = {
    kitty = {
      enable = true;
      font = {
        name = "FiraCode Nerd Font Mono";
        size = 16;
      };
      package = pkgs.kitty;
      settings = {
        cursor_blink_interval = 0.75;
        cursor_shape = "block";
        cursor_shape_unfocused = "hollow";
        cursor_stop_blinking_after = 0;
        confirm_os_window_close = 0;
        hide_window_decorations = hideWindowDecorations;
        scrollbar = "scrolled";
        scrollbar_handle_opacity = 0.50;
        scrollback_lines = 65536;
        shell = lib.mkIf host.is.darwin "${pkgs.fish}/bin/fish --interactive";
        draw_minimal_borders = "yes";
        window_border_width = "0pt";
        window_margin_width = 0;
        single_window_margin_width = 0;
        sync_to_monitor = "yes";
        term = "xterm-kitty"; # Use xterm-kitty to enable Kitty graphics protocol features
        # Mouse
        copy_on_select = true;
        mouse_hide_wait = 0;
        strip_trailing_spaces = "smart";
        wheel_scroll_multiplier = 2;
        # Bell
        enable_audio_bell = "no";
        visual_bell_duration = 0.25;
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

        # Send proper escape sequences for Enter key modifiers (for OpenCode)
        map shift+enter send_text all \x1b[13;2u
        map ctrl+enter send_text all \x1b[13;5u

        # Send proper escape sequences for Shift+Ins and Shift+Del (for Neovim CUA keybindings)
        # Without this, Kitty intercepts these for its own clipboard operations
        map shift+insert send_text all \x1b[2;2~
        map shift+delete send_text all \x1b[3;2~

        # Ensure Ctrl+Shift+P is passed through to applications (not intercepted by Kitty)
        # This is needed for Neovim command palette
        map ctrl+shift+p send_text all \x1b[80;6u
      '';
    };
    fuzzel = lib.mkIf config.programs.fuzzel.enable {
      settings.main.terminal = "${lib.getExe config.programs.kitty.package}";
    };
  };

  wayland.windowManager = {
    hyprland = lib.mkIf config.wayland.windowManager.hyprland.enable {
      settings = {
        bind = [
          "$mod, T, exec, ${lib.getExe config.programs.kitty.package}"
        ];
      };
    };
    wayfire = lib.mkIf config.wayland.windowManager.wayfire.enable {
      settings = {
        command = {
          # Super+T launches a terminal
          binding_terminal = "<super> KEY_T";
          command_terminal = "${lib.getExe config.programs.kitty.package}";
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
  xdg = {
    terminal-exec = {
      settings = {
        default = [ "kitty.desktop" ];
      };
    };
  };
}
