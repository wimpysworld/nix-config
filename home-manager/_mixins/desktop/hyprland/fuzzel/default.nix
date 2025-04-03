{ hostname, lib, pkgs, ... }:
let
  fontSize = if (hostname == "phasma" || hostname =="vader") then "30" else "18";
  # Workaround Nix failing to evaluate the DATA in fuzzel-emoji
  fuzzelEmoji = pkgs.writeTextFile {
    name = "fuzzel-emoji";
    executable = true;
    destination = "/bin/fuzzel-emoji";
    text = builtins.readFile ./fuzzel-emoji.sh;
  };
  fuzzelWifi = pkgs.writeShellApplication {
    name = "fuzzel-wifi";
    runtimeInputs = with pkgs; [
      gawk
      gnugrep
      gnused
      notify-desktop
      networkmanager
    ];
    text = builtins.readFile ./fuzzel-wifi.sh;
  };
in
{
  # Fuzzel menus for app launcher, emoji picker, wifi manager, clipboard manager, etc
  home = {
    packages = with pkgs; [
      fuzzelEmoji
      fuzzelWifi
      wl-clipboard
      wtype
    ];
  };
  programs = {
    fuzzel = {
      enable = true;
      settings = {
        main = {
          filter-desktop = true;
          font = "FiraCode Nerd Font Mono:size=${fontSize}";
          lines = 16;
          terminal = "foot";
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
        "CTRL ALT, H, exec, cliphist list | fuzzel --dmenu --prompt '󱘢 ' --width 56 | cliphist decode | ${pkgs.wl-clipboard-rs}/bin/wl-copy --primary --regular --trim-newline"
        "CTRL ALT, E, exec, fuzzel-emoji"
        "CTRL ALT, R, exec, $SHELL -c history | uniq | fuzzel --dmenu --prompt '󱆃 ' --width 56 | ${pkgs.wl-clipboard-rs}/bin/wl-copy --primary --regular --trim-newline"
        "CTRL ALT, W, exec, fuzzel-wifi"
      ];
    };
  };
}
