{
  lib,
  pkgs,
  ...
}:
{
  # Hyprlock is a lockscreen that is a part of the hyprland suite
  # This config provides a lockscreen with a background image, input field, and labels
  programs = {
    hyprlock = {
      enable = true;
      settings = {
        general = {
          grace = 5;
          hide_cursor = true;
        };
        background = [{
          path = "/etc/backgrounds/DeterminateColorway-1920x1080.png";
        }];
        input-field = [{
          size = "480, 108";
          outer_color = "rgba(147, 153, 178, 1.0)";
          #inner_color = "rgba(88, 91, 112. 1.0)";
          font_color = "rgba(127, 132, 156, 1.0)";
          placeholder_text = "enter password";
        }];
        label = [{
          text = "🔐";
          color = "rgba(249, 226, 175, 1.0)";
          font_family = "Work Sans";
          font_size = 192;
          text_align = "center";
          halign = "center";
          valign = "center";
          position = "0, 300";
        }
        {
          text = "$TIME";
          color = "rgba(205, 214, 244, 1.0)";
          font_family = "Work Sans";
          font_size = 96;
          text_align = "center";
          halign = "center";
          valign = "center";
          position = "0, -250";
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
            on-timeout = "${pkgs.unstable.hyprland}/bin/hyprctl dispatch dpms off";
            on-resume = "${pkgs.unstable.hyprland}/bin/hyprctl dispatch dpms on";
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
