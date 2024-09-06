{ hostname, lib, pkgs, ... }:
let
  fontSize = if (hostname == "phasma" || hostname =="vader") then "30" else "18";
in
{
  # Fuzzel powered app launcher, emoji picker and clipboard manager for Hyprland
  home = {
    packages = with pkgs; [
      bemoji
      wl-clipboard-rs
      wtype
    ];
    sessionVariables = {
      BEMOJI_PICKER_CMD = "${lib.getExe pkgs.fuzzel} --dmenu --width 48";
    };
  };
  programs = {
    fuzzel = {
      enable = true;
      catppuccin.enable = true;
      settings = {
        main = {
          filter-desktop = true;
          font = "FiraCode Nerd Font Mono:size=${fontSize}";
          lines = 16;
          terminal = "alacritty";
          tabs = 2;
          width = 32;
          horizontal-pad = 32;
          vertical-pad = 32;
          inner-pad = 32;
        };
        border = {
          width = 2;
          radius = 8;
        };
      };
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
      bindr = [ "$mod, $mod_L, exec, ${pkgs.procps}/bin/pkill fuzzel || fuzzel --prompt '󱓞 '" ];
      bind = [
        "$mod, SPACE, exec, fuzzel --prompt '󰌧 ' --show-actions"
        "CTRL ALT, H, exec, cliphist list | fuzzel --dmenu --prompt '󱘢 ' --width 56 | cliphist decode | wl-copy --primary --regular --trim-newline"
        "CTRL ALT, E, exec, ${lib.getExe pkgs.bemoji} --clip --noline --type --hist-limit 8"
        "CTRL ALT, R, exec, history | uniq | fuzzel --dmenu --prompt '󱆃 ' --width 56 | wl-copy --primary --regular --trim-newline"
      ];
    };
  };
}
