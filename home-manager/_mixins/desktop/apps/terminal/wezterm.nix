{
  catppuccinPalette,
  config,
  lib,
  ...
}:
let
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
  catppuccin.wezterm.enable = config.programs.wezterm.enable;

  # Secondary terminal for testing projects that use Sixel graphics. Kitty
  # remains the default; wezterm mirrors its Catppuccin Mocha theme and font.
  programs.wezterm = {
    enable = true;
    enableBashIntegration = false;
    enableZshIntegration = false;
    settings = {
      check_for_updates = false;

      # Wezterm PR 7737 introduced these cursor trail settings.
      # https://github.com/wezterm/wezterm/pull/7737
      cursor_smear = true;
      cursor_smear_gradient = true;
      cursor_trail_size = 1.0;
      cursor_trail_style = "PixieDust";
      cursor_animation_duration = 0.575;
      # Set particle opacity, where 1.0 is fully opaque (default: 0.6).
      cursor_vfx_opacity = 0.475;
      # Set how long particles persist in seconds (default: 0.35).
      cursor_vfx_particle_lifetime = 0.375;
      # Set the particles spawned per cell of movement (default: 0.7).
      cursor_vfx_particle_density = 0.725;
      # Set the initial particle speed in cells per second (default: 8.0).
      cursor_vfx_particle_speed = 8.0;
      # Set particle diameter as a fraction of cell width (default: 0.5).
      cursor_vfx_particle_size = 0.5;

      default_cursor_style = "BlinkingBlock";
      animation_fps = 30;
      cursor_blink_ease_in = "EaseIn";
      cursor_blink_ease_out = "EaseOut";
      cursor_blink_rate = 750;

      hide_tab_bar_if_only_one_tab = true;
      scrollback_lines = 65536;
      term = "wezterm";
      window_decorations = if hideWindowDecorations then "NONE" else "TITLE | RESIZE";
      window_padding = {
        left = "2px";
        right = "2px";
        top = "2px";
        bottom = "2px";
      };

      colors = {
        cursor_border = getColor "flamingo";
        tab_bar = {
          inactive_tab_edge = getColor "surface0";
          active_tab = {
            bg_color = getColor "blue";
            fg_color = getColor "crust";
          };
          inactive_tab = {
            bg_color = getColor "mantle";
            fg_color = getColor "subtext1";
          };
          inactive_tab_hover = {
            bg_color = getColor "surface0";
            fg_color = getColor "text";
          };
          new_tab = {
            bg_color = getColor "surface0";
            fg_color = getColor "text";
          };
          new_tab_hover = {
            bg_color = getColor "blue";
            fg_color = getColor "crust";
          };
        };
      };
      font = lib.generators.mkLuaInline ''wezterm.font("FiraCode Nerd Font Mono")'';
      font_size = 16;
      window_frame = {
        font = lib.generators.mkLuaInline ''wezterm.font({ family = "FiraCode Nerd Font Mono", weight = "Bold" })'';
        font_size = 12;
        active_titlebar_bg = getColor "mantle";
        inactive_titlebar_bg = getColor "crust";
        active_titlebar_fg = getColor "text";
        inactive_titlebar_fg = getColor "subtext0";
        active_titlebar_border_bottom = getColor "blue";
        inactive_titlebar_border_bottom = getColor "surface0";
        button_fg = getColor "text";
        button_bg = getColor "mantle";
        button_hover_fg = getColor "crust";
        button_hover_bg = getColor "blue";
      };
      keys = [
        {
          key = "Enter";
          mods = "SHIFT";
          action = lib.generators.mkLuaInline ''wezterm.action.SendString("\n")'';
        }
        {
          key = "Enter";
          mods = "CTRL";
          action = lib.generators.mkLuaInline ''wezterm.action.SendString("\x1b[13;5u")'';
        }
        {
          key = "Insert";
          mods = "SHIFT";
          action = lib.generators.mkLuaInline ''wezterm.action.SendString("\x1b[2;2~")'';
        }
        {
          key = "Delete";
          mods = "SHIFT";
          action = lib.generators.mkLuaInline ''wezterm.action.SendString("\x1b[3;2~")'';
        }
        {
          key = "p";
          mods = "CTRL|SHIFT";
          action = lib.generators.mkLuaInline ''wezterm.action.SendString("\x1b[80;6u")'';
        }
      ];
      use_fancy_tab_bar = true;
    };
  };
}
