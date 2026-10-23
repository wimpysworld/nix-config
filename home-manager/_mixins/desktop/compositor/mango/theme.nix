{
  catppuccinPalette,
  config,
  lib,
  ...
}:
let
  inherit (config.noughty) host;
  inherit (import ./config-format.nix { inherit catppuccinPalette lib; }) mixMangoColor toMangoColor;

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

      # Blur, with neutral colour parameters because the defaults tint it.
      # The optimised blur draws an opaque cached copy of the wallpaper,
      # which hides the windows below a layer surface, so it stays off.
      blur = true;
      blur_layer = true;
      blur_optimized = false;
      blur_params_num_passes = 3;
      blur_params_radius = 8;
      blur_params_noise = 0.02;
      blur_params_brightness = 1.0;
      blur_params_contrast = 1.0;
      blur_params_saturation = 1.0;

      # Shadows. Tiled windows get none, because the
      # narrow gaps would let a shadow fall onto the neighbour window.
      # Floating windows and fuzzel get a soft centred glow, like the
      # Wayfire winshadows glow. Mango moves each shadow shadows_size
      # pixels right and down, so the negative positions centre it.
      # Mango gives no layer shadow to rofi, wleave or Waybar, and the
      # layer rules turn it off for SwayNC and the others.
      shadows = true;
      layer_shadows = true;
      shadow_only_floating = true;
      shadows_size = 24;
      shadows_blur = 24;
      shadows_position_x = -24;
      shadows_position_y = -20;
      shadows_color = toMangoColor "crust" 0.55;

      # Opacity and dimming. The dim strength is 2.5 percent, in crust
      # rather than black.
      focused_opacity = 1.0;
      unfocused_opacity = 1.0;
      dim_enable = true;
      dim_focused_color = "0x00000000";
      dim_unfocused_color = toMangoColor "crust" 0.025;

      # Geometry: radius, border and gaps.
      border_radius = 8;
      no_radius_when_single = false;
      no_border_when_single = false;
      border_px = 2;
      gap_inner_horizontal = 5;
      gap_inner_vertical = 5;
      gap_outer_horizontal = 5;
      gap_outer_vertical = 5;
      smart_gaps = false;

      # Colours by window state
      root_color = toMangoColor "base" 1.0;
      focus_color = toMangoColor "blue" 1.0;
      border_color = toMangoColor "surface1" 1.0;
      urgent_color = toMangoColor "red" 1.0;
      maximized_screen_color = toMangoColor "green" 1.0;
      drop_color = toMangoColor "blue" 0.33;
      split_color = toMangoColor "peach" 1.0;

      # Overview and jump labels
      overview_gap_inner = 8;
      overview_gap_outer = 40;
      jump_labels = "HJKLASDFGQWERTYUIOPZXCVBNM";
      jump_label_decorate_font_desc = "FiraCode Nerd Font Mono Bold 18";
      jump_label_decorate_fg_color = toMangoColor "crust" 1.0;
      jump_label_decorate_bg_color = toMangoColor "blue" 1.0;
      jump_label_decorate_focus_fg_color = toMangoColor "crust" 1.0;
      jump_label_decorate_focus_bg_color = toMangoColor "pink" 1.0;
      jump_label_decorate_border_color = toMangoColor "surface2" 1.0;
      jump_label_decorate_border_width = 2;
      jump_label_decorate_corner_radius = 8;
      jump_label_decorate_padding_x = 12;
      jump_label_decorate_padding_y = 6;
      # Hide the title label under the Alt-Tab switcher and overcircle view.
      title_message_bar_height = 0;

      # Tab bar, which monocle, deck and vertical_deck draw above stacked
      # windows. Mango has no gap between tabs or between the bar and its
      # window, and it fills each tab inside its border. A transparent
      # border therefore gives each tab a 3 pixel margin, so the tabs show
      # as separate pills: 6 pixels apart and 3 pixels above the window.
      # The bar is 6 pixels taller to keep the text area. Mango has one
      # border colour for every tab and no urgent tab colour, so the tabs
      # differ by fill and text. The focused tab is a solid dark navy, a
      # little blue mixed into crust, with blue text. Other tabs are a
      # translucent crust with dimmed blue text, so they recede.
      tab_bar_height = 38;
      tab_bar_decorate_font_desc = "FiraCode Nerd Font Mono Bold 12";
      tab_bar_decorate_fg_color = toMangoColor "blue" 0.55;
      tab_bar_decorate_bg_color = toMangoColor "crust" 0.6;
      tab_bar_decorate_focus_fg_color = toMangoColor "blue" 1.0;
      tab_bar_decorate_focus_bg_color = mixMangoColor "blue" "crust" 0.18 0.95;
      tab_bar_decorate_border_color = toMangoColor "base" 0.0;
      tab_bar_decorate_border_width = 3;
      tab_bar_decorate_corner_radius = 8;
      tab_bar_decorate_padding_x = 12;
      tab_bar_decorate_padding_y = 0;
    };
  };
}
