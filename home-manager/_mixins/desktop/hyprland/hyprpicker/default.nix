{
  config,
  lib,
  pkgs,
  ...
}:
{
  # hyprpicker is a color picker for Hyprland
  home = {
    packages = with pkgs; [
      hyprpicker
    ];
  };
  wayland.windowManager.hyprland = {
    settings = {
      bind = [
        bind = $mod, P, exec, hyprpicker | wl-copy --primary --regular --trim-newline
      ];
    };
  };
}
