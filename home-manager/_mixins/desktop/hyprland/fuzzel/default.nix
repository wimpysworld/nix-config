{
  config,
  lib,
  pkgs,
  ...
}:
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
      bindr = [
        "$mod, SUPER_L, exec, fuzzel --prompt '🖥️ Desktop Apps > '"
      ];
      bind = [
        "$mod, SPACE, exec, fuzzel --prompt '🚀 Desktop Actions > ' --show-actions"
        "CTRL ALT, C, exec, cliphist list | fuzzel --dmenu --prompt '📋️ Clipboard > ' | cliphist decode | wl-copy --primary --regular --trim-newline"
        "CTRL ALT, E, exec, ${lib.getExe pkgs.bemoji} --clip --noline --type --hist-limit 32"
        "CTRL ALT, R, exec, history | uniq | fuzzel --dmenu --prompt '💲 Command History > ' | wl-copy --primary --regular --trim-newline"
      ];
    };
  };
}
