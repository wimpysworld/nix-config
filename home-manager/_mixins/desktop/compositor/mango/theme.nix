{
  catppuccinPalette,
  config,
  lib,
  ...
}:
let
  inherit (config.noughty) host;
  inherit (import ./config-format.nix { inherit catppuccinPalette lib; }) toMangoColor;

  # Each animation curve is a cubic bezier with four control values.
  curves = {
    overshoot = "0.34,1.56,0.64,1";
    glide = "0.16,1,0.3,1";
    wind = "0.22,1,0.36,1";
    exit = "0.4,0,1,1";
    ease = "0.25,0.1,0.25,1";
  };
in
{
  config = lib.mkIf (host.desktop == "mango") {
    wayland.windowManager.mango.settings = {
      # Animations
      animations = true;
      layer_animations = true;
      animation_type_open = "zoom";
      animation_type_close = "zoom";
      layer_animation_type_open = "slide";
      layer_animation_type_close = "fade";
      animation_fade_in = true;
      animation_fade_out = true;
      zoom_initial_ratio = 0.85;
      zoom_end_ratio = 0.9;
      fade_in_begin_opacity = 0;
      fade_out_begin_opacity = 1;
      tag_animation_direction = 1;
      animation_duration_open = 350;
      animation_duration_close = 240;
      animation_duration_move = 320;
      animation_duration_tag = 320;
      # The focus colour fade needs a duration; the default is 0.
      animation_duration_focus = 180;
      animation_curve_open = curves.overshoot;
      animation_curve_move = curves.glide;
      animation_curve_tag = curves.wind;
      animation_curve_close = curves.exit;
      animation_curve_focus = curves.ease;
      animation_curve_opacity_fade_in = curves.wind;
      animation_curve_opacity_fade_out = curves.exit;

      # Blur, with neutral colour parameters because the defaults tint it
      blur = true;
      blur_layer = true;
      blur_optimized = true;
      blur_params_num_passes = 3;
      blur_params_radius = 8;
      blur_params_noise = 0.02;
      blur_params_brightness = 1.0;
      blur_params_contrast = 1.0;
      blur_params_saturation = 1.0;

      # Shadows
      shadows = true;
      layer_shadows = true;
      shadow_only_floating = false;
      shadows_size = 18;
      shadows_blur = 28;
      shadows_position_x = 0;
      shadows_position_y = 6;
      shadows_color = toMangoColor "crust" 0.8;

      # Opacity and dimming
      focused_opacity = 1.0;
      unfocused_opacity = 0.92;
      dim_enable = true;
      dim_focused_color = "0x00000000";
      dim_unfocused_color = toMangoColor "base" 0.2;

      # Geometry
      border_radius = 12;
      no_radius_when_single = false;
      no_border_when_single = false;
      border_px = 3;
      gap_inner_horizontal = 6;
      gap_inner_vertical = 6;
      gap_outer_horizontal = 12;
      gap_outer_vertical = 12;
      smart_gaps = false;

      # Colours by window state. The thumbnail switcher draws the selected
      # tile with focus_color and the other tiles with border_color.
      root_color = toMangoColor "base" 1.0;
      focus_color = toMangoColor "mauve" 1.0;
      border_color = toMangoColor "surface1" 1.0;
      urgent_color = toMangoColor "red" 1.0;
      maximized_screen_color = toMangoColor "green" 1.0;
      drop_color = toMangoColor "mauve" 0.33;
      split_color = toMangoColor "peach" 1.0;

      # Overview and jump labels
      overview_gap_inner = 8;
      overview_gap_outer = 40;
      jump_labels = "HJKLASDFGQWERTYUIOPZXCVBNM";
      jump_label_decorate_font_desc = "FiraCode Nerd Font Mono Bold 18";
      jump_label_decorate_fg_color = toMangoColor "crust" 1.0;
      jump_label_decorate_bg_color = toMangoColor "mauve" 1.0;
      jump_label_decorate_focus_fg_color = toMangoColor "crust" 1.0;
      jump_label_decorate_focus_bg_color = toMangoColor "pink" 1.0;
      jump_label_decorate_border_color = toMangoColor "surface2" 1.0;
      jump_label_decorate_border_width = 2;
      jump_label_decorate_corner_radius = 8;
      jump_label_decorate_padding_x = 12;
      jump_label_decorate_padding_y = 6;
    };
  };
}
