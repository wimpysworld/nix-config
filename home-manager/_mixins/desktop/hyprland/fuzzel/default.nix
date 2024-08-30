{ lib, pkgs, ... }:
{
  # Fuzzel powered app launcher, emoji picker and clipboard manager for Hyprland
  home = {
    packages = with pkgs; [
      bemoji
      wl-clipboard-rs
    ];
    sessionVariables = {
      BEMOJI_PICKER_CMD = "${lib.getExe pkgs.fuzzel} --dmenu";
    };
  };
  programs = {
    fuzzel = {
      enable = true;
      catppuccin.enable = true;
    };
  };
  services = {
    cliphist = {
      enable = true;
      systemdTarget = "hyprland-session.target";
    };
  };
  wayland.windowManager.hyprland = {
    settings = {
      bindr = [ "$mod, SUPER_L, exec, fuzzel --prompt '󰵆 > '" ];
      bind = [
        "$mod, SPACE, exec, fuzzel --prompt '󰌧 > ' --show-actions"
        "CTRL ALT, C, exec, cliphist list | fuzzel --dmenu --prompt '󰅌 > ' | cliphist decode | wl-copy --primary --regular --trim-newline"
        "CTRL ALT, E, exec, ${lib.getExe pkgs.bemoji} --clip --noline --type --hist-limit 32"
        "CTRL ALT, R, exec, history | uniq | fuzzel --dmenu --prompt '󱆃 > ' | wl-copy --primary --regular --trim-newline"
      ];
    };
  };
}
