{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  # Walker is a launcher that has modules for applications, clipboard, emojis, runner and more.
  imports = [
    inputs.walker.homeManagerModules.default
  ];
  programs = {
    walker = {
      enable = true;
      runAsService = true;
      config = {
        show_initial_entries = true;
        fullscreen = true;
        scrollbar_policy = "external";
        activation_mode.use_alt = true;
        search = {
          hide_icons = false;
          hide_spinner = true;
        };
        align = {
          width = 960;
          horizontal = "center";
          vertical = "center";
          margins.top = 0;
        };
        list = {
          height = 540;
          fixed_height = true;
          always_show = true;
        };
        icons.hide = false;
      };
    };
  };
  wayland.windowManager.hyprland = {
    settings = {
      bindr = [
        "$mod, SUPER_L, exec, walker -m applications"
      ];
      bind = [
        "CTRL ALT, C, exec, walker -m clipboard"
      ];
    };
  };
}
