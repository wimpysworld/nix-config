{ hostname, lib, pkgs, ... }:
let
  passwordPrompt = if hostname == "tanis" then
    "󰈷"
  else
    "󰌋";
  catSize = if hostname == "vader" then
    320
  else if hostname == "phasma" then
    430
  else
    240;
  catPosition = if hostname == "vader" then
    "0, -1124"
  else if hostname == "phasma" then
    "0, -460"
  else if hostname == "tanis" then
    "0, -424"
  else
    "0, -316";
  catResolution = if hostname == "vader" then
    "2560"
  else if hostname == "phasma" then
    "3440"
  else
    "1920";
  monitor = if hostname == "vader" then
    "DP-1"
  else if hostname == "phasma" then
    "DP-1"
  else if (hostname == "shaa" || hostname == "tanis") then
    "eDP-1"
  else
    "";
in
{
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
        background = [
          {
            path = "screenshot";
            blur_passes = 3;
            blur_size = 12;
            color = "rgb(1e1e2e)";
          }
        ];
        image = [
          {
            # Avatar
            monitor = monitor;
            path = "$HOME/.face";
            border_size = 2;
            border_color = "rgba(137, 180, 250, 0.7)";
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
            monitor = monitor;
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
            monitor = monitor;
            text = ''cmd[update:3600000] echo -e "$(date +"%a, %d %b")"'';
            color = "rgba(205, 214, 244, 0.9)";
            font_size = 25;
            font_family = "Work Sans Bold";
            position = "0, 440";
            halign = "center";
            valign = "center";
          }
          {
            # Weather (30min)
            monitor = monitor;
            text = ''cmd[update:1800000] ${lib.getExe pkgs.curl} -sLq "wttr.in?format=%c+%t"'';
            color = "rgba(205, 214, 244, 0.9)";
            font_size = 14;
            font_family = "Work Sans Bold";
            position = "0, 420";
            halign = "center";
            valign = "center";
          }
          {
            # Time Border left
            monitor = monitor;
            text = "$TIME";
            color = "rgba(17, 17, 27, 0.8)";
            font_size = 120;
            font_family = "FiraCode Nerd Font Mono Bold";
            position = "-4, 250";
            halign = "center";
            valign = "center";
            zindex = 0;
          }
          {
            # Time Border right
            monitor = monitor;
            text = "$TIME";
            color = "rgba(17, 17, 27, 0.8)";
            font_size = 120;
            font_family = "FiraCode Nerd Font Mono Bold";
            position = "4, 250";
            halign = "center";
            valign = "center";
            zindex = 0;
          }
          {
            # Time Border up
            monitor = monitor;
            text = "$TIME";
            color = "rgba(17, 17, 27, 0.8)";
            font_size = 120;
            font_family = "FiraCode Nerd Font Mono Bold";
            position = "0, 246";
            halign = "center";
            valign = "center";
            zindex = 0;
          }
          {
            # Time Border down
            monitor = monitor;
            text = "$TIME";
            color = "rgba(17, 17, 27, 0.8)";
            font_size = 120;
            font_family = "FiraCode Nerd Font Mono Bold";
            position = "0, 254";
            halign = "center";
            valign = "center";
            zindex = 0;
          }
          {
            # Time
            monitor = monitor;
            text = "$TIME";
            color = "rgba(205, 214, 244, 0.9)";
            font_size = 120;
            font_family = "FiraCode Nerd Font Mono Bold";
            position = "0, 250";
            halign = "center";
            valign = "center";
            zindex = 1;
          }
          {
            # Username
            monitor = monitor;
            text = ''<span foreground="##a6e3a1"></span>  $DESC'';
            color = "rgba(147, 153, 178, 1.0)";
            font_size = 18;
            font_family = "Work Sans";
            position = "0, -130";
            halign = "center";
            valign = "center";
          }
        ];
        # Username box
        shape = [
          {
            monitor = monitor;
            size = "420, 60";
            position = "0, -130";
            color = "rgba(69, 71, 90, 1.0)";
            rounding = 8;
            border_size = 2;
            border_color = "rgba(49, 50, 68, 1.0)";
            rotate = 0;
            xray = false; # do not make a "hole" in the background
            halign = "center";
            valign = "center";
          }
        ];
        # Password
        input-field = [
          {
            monitor = monitor;
            size = "420, 60";
            position = "0, -210";
            outline_thickness = 2;
            dots_size = 0.35;
            dots_spacing = 0.25;
            dots_center = true;
            fade_on_empty = false;
            placeholder_text = ''<span foreground="##f9e2af"><big>  ${passwordPrompt}  </big></span>'';
            fail_text = ''<span foreground="##f38ba8">󰀧</span>  <i>$FAIL</i> <span foreground="##f38ba8"><b>($ATTEMPTS)</b></span>'';
            fail_timeout = 10000; # milliseconds before fail_text and fail_color disappears
            fail_transition = 250; # transition time in ms between normal outer_color and fail_color
            hide_input = false;
            halign = "center";
            valign = "center";
            rounding = 8;
            outer_color = "rgba(137, 180, 250, 1.0)";
            inner_color = "rgba(88, 91, 112, 1.0)";
            font_color = "rgba(205, 214, 244, 1.0)";
            capslock_color = "rgba(250, 179, 135, 1.0)";
            check_color = "rgba(116, 199, 236, 1.0)";
            fail_color = "rgba(245, 194, 231, 1.0)";
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
