{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  hideWindowDecorations =
    if config.wayland.windowManager.wayfire.enable then
      false
    else if config.wayland.windowManager.hyprland.enable then
      true
    else
      false;
in
{
  catppuccin.kitty.enable = config.programs.kitty.enable;

  programs.kitty = {
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
      term = "xterm-kitty"; # Use xterm-kitty to enable Kitty graphics protocol features.
      # Configure mouse behaviour.
      copy_on_select = true;
      mouse_hide_wait = 0;
      strip_trailing_spaces = "smart";
      wheel_scroll_multiplier = 2;
      # Configure bell behaviour.
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

      # Send proper escape sequences for Enter key modifiers in OpenCode.
      map shift+enter send_text all \x1b[13;2u
      map ctrl+enter send_text all \x1b[13;5u

      # Send proper escape sequences for Shift+Ins and Shift+Del.
      # Without this, Kitty intercepts these for its own clipboard operations.
      map shift+insert send_text all \x1b[2;2~
      map shift+delete send_text all \x1b[3;2~

      # Pass Ctrl+Shift+P through to applications instead of intercepting it.
      map ctrl+shift+p send_text all \x1b[80;6u
    '';
  };
}
