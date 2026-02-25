{
  catppuccinPalette,
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  inherit (host) display;
  palette = catppuccinPalette;
  mkRgb = colorName: "rgb(${palette.getHyprlandColor colorName})";
  inherit (palette) mkRgba;
  mkPangoHex = colorName: "#${palette.getColor colorName}";
  catSize =
    if display.primaryIsPortrait then
      320
    else if display.primaryIsUltrawide then
      430
    else
      240;
  catPosition =
    if display.primaryIsPortrait then
      "0, -1124"
    else if display.primaryIsUltrawide then
      "0, -460"
    else if display.primaryHeight == 1200 then
      "0, -424"
    else
      "0, -316";
  catResolution = toString display.primaryWidth;
  monitor = display.primaryOutput;
  unlockGlyph = if noughtyLib.hostHasTag "fprintd" then "󰈷" else "󰌋";
in
lib.mkIf host.is.linux {
  # Hyprlock is a lockscreen that is a part of the hyprland suite
  programs = {
    hyprlock = {
      enable = true;
      settings = {
        general = {
          disable_loading_bar = true;
          grace = 5;
          hide_cursor = true;
          immediate_render = true;
          no_fade_in = false;
          no_fade_out = false;
        };
        auth = lib.mkIf (noughtyLib.hostHasTag "fprintd") {
          fingerprint = {
            enabled = true;
            ready_message = ""; #Place your finger on the Touch ID sensor
            present_message = "Verifying your identity...";
            retry_delay = 250;
          };
        };
        background = [
          {
            path = "screenshot";
            blur_passes = 3;
            blur_size = 12;
            color = mkRgb "base";
          }
        ];
        image = [
          {
            # Avatar
            inherit monitor;
            path = "$HOME/.face";
            border_size = 2;
            border_color = mkRgba "blue" "0.7";
            size = 140;
            rounding = -1;
            rotate = 0;
            reload_time = -1;
            position = "0, 40";
            halign = "center";
            valign = "center";
          }
          {
            # Catppuccin
            inherit monitor;
            path = "/etc/backgrounds/Cat-${catResolution}px.png";
            border_size = 0;
            rounding = 0;
            rotate = 0;
            reload_time = -1;
            size = catSize;
            position = catPosition;
            halign = "left";
            valign = "center";
          }
        ];
        label = [
          {
            # Date (1 hour)
            inherit monitor;
            text = ''cmd[update:3600000] echo -e "$(date +"%a, %d %b")"'';
            color = mkRgba "text" "0.9";
            font_size = 25;
            font_family = "Work Sans Bold";
            position = "0, 440";
            halign = "center";
            valign = "center";
          }
          {
            # Time Border left
            inherit monitor;
            text = "$TIME";
            color = mkRgba "crust" "0.8";
            font_size = 120;
            font_family = "FiraCode Nerd Font Mono Bold";
            position = "-4, 250";
            halign = "center";
            valign = "center";
            zindex = 0;
          }
          {
            # Time Border right
            inherit monitor;
            text = "$TIME";
            color = mkRgba "crust" "0.8";
            font_size = 120;
            font_family = "FiraCode Nerd Font Mono Bold";
            position = "4, 250";
            halign = "center";
            valign = "center";
            zindex = 0;
          }
          {
            # Time Border up
            inherit monitor;
            text = "$TIME";
            color = mkRgba "crust" "0.8";
            font_size = 120;
            font_family = "FiraCode Nerd Font Mono Bold";
            position = "0, 246";
            halign = "center";
            valign = "center";
            zindex = 0;
          }
          {
            # Time Border down
            inherit monitor;
            text = "$TIME";
            color = mkRgba "crust" "0.8";
            font_size = 120;
            font_family = "FiraCode Nerd Font Mono Bold";
            position = "0, 254";
            halign = "center";
            valign = "center";
            zindex = 0;
          }
          {
            # Time
            inherit monitor;
            text = "$TIME";
            color = mkRgba "text" "0.9";
            font_size = 120;
            font_family = "FiraCode Nerd Font Mono Bold";
            position = "0, 250";
            halign = "center";
            valign = "center";
            zindex = 1;
          }
          {
            # Username
            inherit monitor;
            text = ''<span foreground="${mkPangoHex "green"}">󰝴</span> $DESC'';
            color = mkRgba "overlay2" "1.0";
            font_size = 18;
            font_family = "FiraCode Nerd Font Propo";
            position = "0, -130";
            halign = "center";
            valign = "center";
          }
          {
            # Fingerprint prompt (only rendered when fprintd sends a message)
            inherit monitor;
            text = "$FPRINTPROMPT";
            color = mkRgba "green" "0.9";
            font_size = 14;
            font_family = "Work Sans";
            position = "0, -280";
            halign = "center";
            valign = "center";
          }
        ];
        # Username box
        shape = [
          {
            inherit monitor;
            size = "420, 60";
            position = "0, -130";
            color = mkRgba "surface1" "1.0";
            rounding = 8;
            border_size = 2;
            border_color = mkRgba "surface0" "1.0";
            rotate = 0;
            xray = false; # do not make a "hole" in the background
            halign = "center";
            valign = "center";
          }
        ];
        # Password
        input-field = [
          {
            inherit monitor;
            size = "420, 60";
            position = "0, -210";
            outline_thickness = 2;
            dots_size = 0.35;
            dots_spacing = 0.25;
            dots_center = true;
            fade_on_empty = false;
            placeholder_text = ''<span foreground="${mkPangoHex "yellow"}"><big>  ${unlockGlyph}  </big></span>'';
            fail_text = ''<span foreground="${mkPangoHex "red"}">󰀧</span>  <i>$FAIL</i> <span foreground="${mkPangoHex "red"}"><b>($ATTEMPTS)</b></span>'';
            fail_timeout = 3000; # milliseconds before fail_text and fail_color disappears
            fail_transition = 500; # transition time in ms between normal outer_color and fail_color
            hide_input = false;
            halign = "center";
            valign = "center";
            rounding = 8;
            outer_color = mkRgba "blue" "1.0";
            inner_color = mkRgba "surface2" "1.0";
            font_color = mkRgba "text" "1.0";
            capslock_color = mkRgba "peach" "1.0";
            check_color = mkRgba "sapphire" "1.0";
            fail_color = mkRgba "pink" "1.0";
          }
        ];
      };
    };
  };
  services = {
    hypridle = {
      enable = true;
      settings = {
        general = {
          lock_cmd = "${lib.getExe pkgs.hyprlock}";
          before_sleep_cmd = "${lib.getExe pkgs.hyprlock}";
        };
        listener = [
          {
            timeout = 300;
            on-timeout = "${lib.getExe pkgs.hyprlock}";
          }
          {
            timeout = 305;
            on-timeout = "hyprctl dispatch dpms off";
            on-resume = "hyprctl dispatch dpms on";
          }
        ];
      };
    };
  };
  wayland.windowManager.hyprland = {
    settings = {
      bind = [
        "$mod, L, exec, ${lib.getExe pkgs.hyprlock} --immediate"
        "CTRL ALT, L, exec, ${lib.getExe pkgs.hyprlock} --immediate"
      ];
    };
  };
}
