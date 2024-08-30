{
  lib,
  pkgs,
  ...
}:
let
  batteryLockInfo = pkgs.writeShellApplication {
    name = "battery-lock-info";
    runtimeInputs = with pkgs; [
      coreutils-full
    ];
    text = ''
      battery="BAT0"

      # Get the battery status (Charging or Discharging)
      battery_status=$(cat /sys/class/power_supply/$battery/status)
      # Check if the battery is charging
      if [ "$battery_status" = "Charging" ]; then
        battery_icon="󰂄"
      else
        # Get the current battery percentage
        battery_capacity=$(cat /sys/class/power_supply/$battery/capacity)
        icon_index=$((battery_capacity / 10))
        # Define the battery icons for each 10% segment
        #battery_icons=("󰂃" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰁹")
        # Get the corresponding icon
        case $icon_index in
          2)  battery_icon="󰁺";;
          3)  battery_icon="󰁻";;
          4)  battery_icon="󰁼";;
          5)  battery_icon="󰁽";;
          6)  battery_icon="󰁾";;
          7)  battery_icon="󰁿";;
          8)  battery_icon="󰂀";;
          9)  battery_icon="󰂁";;
          10) battery_icon="󰁹";;
          *)  battery_icon="󰂃";;
        esac
      fi
      # Output the battery percentage and icon
      echo "$battery_icon  $battery_capacity%"
    '';
  };
in
{
  # Hyprlock is a lockscreen that is a part of the hyprland suite
  programs = {
    hyprlock = {
      enable = true;
      settings = {
        general = {
          disable_loading_bar = false;
          grace = 5;
          hide_cursor = true;
          no_fade_in = false;
          no_fade_out = false;
        };
        background = [{
          path = "screenshot";
          blur_passes = 3;
          color = "rgb(1e1e2e)";
          contrast = 0.8916;
          brightness = 0.8172;
          vibrancy = 0.1696;
          vibrancy_darkness = 0.0;
        }];
        image = [{
          # Avatar
          path = "$HOME/.face";
          border_size = 2;
          border_color = "rgba(137, 180, 250, 0.7)";
          size = 130;
          rounding = -1;
          rotate = 0;
          reload_time = -1;
          position = "0, 40";
          halign = "center";
          valign = "center";
        }];
        label = [
          {
            # Date (1 hour)
            text = ''cmd[update:3600000] echo -e "$(date +"%a, %d %b")"'';
            color = "#cdd6f4";
            font_size = 25;
            font_family = "Work Sans";
            position = "0, 350";
            halign = "center";
            valign = "center";
          }
          {
            # Time
            text = "$TIME";
            color = "#cdd6f4";
            font_size = 120;
            font_family = "Work Sans Bold";
            position = "0, 250";
            halign = "center";
            valign = "center";
          }
          {
            # Username
            text = "  $DESC";
            color = "#cdd6f4";
            font_size = 18;
            font_family = "Work Sans";
            position = "0, -130";
            halign = "center";
            valign = "center";
          }
          {
            # Weather (30min)
            text = ''cmd[update:1800000] ${lib.getExe pkgs.curl} -sLq "wttr.in/Odiham?format=%c+%t\n"'';
            color = "#cdd6f4";
            font_size = 14;
            font_family = "Work Sans";
            position = "20, 50";
            halign = "left";
            valign = "bottom";
          }
          {
            # Battery (1min)
            text = ''cmd[update:60000] ${lib.getExe batteryLockInfo}'';
            color = "#cdd6f4";
            font_size = 14;
            font_family = "Work Sans";
            position = "-20, 50";
            halign = "right";
            valign = "bottom";
          }
        ];
        # Username box
        shape = [{
          size = "300, 60";
          position = "0, -130";
          color = "rgba(88, 91, 112, 1.0)";
          rounding = 8;
          border_size = 2;
          border_color = "rgba(137, 180, 250, 1.0)";
          rotate = 0;
          xray = false; # do not make a "hole" in the background
          halign = "center";
          valign = "center";
        }];
        # Password
        input-field = [{
          size = "300, 60";
          position = "0, -210";
          outline_thickness = 2;
          dots_size = 0.2;
          dots_spacing = 0.2;
          dots_center = true;
          fade_on_empty = false;
          placeholder_text = ''<span foreground="##cdd6f4">󰌋  enter password</span>'';
          fail_text = "<i>  incorrect <b>($ATTEMPTS)</b></i>";
          fail_timeout = 3000;
          hide_input = false;
          halign = "center";
          valign = "center";
          rounding = 8;
          outer_color = "rgba(137, 180, 250, 1.0)";
          inner_color = "rgba(88, 91, 112, 1.0)";
          font_color = "rgba(205, 214, 244, 1.0)";
          capslock_color = "rgba(249, 226, 175, 1.0)";
          check_color = "rgba(205, 214, 244, 1.0)";
          fail_color = "rgba(243, 139, 168, 1.0)";
        }];
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
