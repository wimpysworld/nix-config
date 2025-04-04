{ config, hostname, inputs, lib, pkgs, ... }:
let
  fontSize = if (hostname == "phasma" || hostname =="vader") then "30" else "18";
  fuzzelActions = pkgs.writeShellApplication {
    name = "fuzzel-actions";
    text = "fuzzel --prompt '󰌧 ' --show-actions";
  };
  fuzzelBluetooth = pkgs.writeShellApplication {
    name = "fuzzel-bluetooth";
    text = ''bzmenu --menu custom --menu-command "fuzzel --dmenu --prompt '󰂯 '"'';
  };
  fuzzelClipboard = pkgs.writeShellApplication {
    name = "fuzzel-clipboard";
    text = "cliphist list | fuzzel --dmenu --prompt '󱘢 ' --width 56 | cliphist decode | wl-copy --primary --trim-newline";
  };
  # Workaround Nix failing to evaluate the DATA in fuzzel-emoji
  fuzzelEmoji = pkgs.writeTextFile {
    name = "fuzzel-emoji";
    executable = true;
    destination = "/bin/fuzzel-emoji";
    text = builtins.readFile ./fuzzel-emoji.sh;
  };
  fuzzelHistory = pkgs.writeShellApplication {
    name = "fuzzel-history";
    text = "$SHELL -c history | uniq | fuzzel --dmenu --prompt '󱆃 ' --width 56 | wl-copy --primary --trim-newline";
  };
  fuzzelHyprshot = pkgs.writeShellApplication {
    name = "fuzzel-hyprshot";
    runtimeInputs = with pkgs; [
      hyprshot
      jq
      satty
    ];
    text = builtins.readFile ./fuzzel-hyprshot.sh;
  };
  fuzzelLauncher = pkgs.writeShellApplication {
    name = "fuzzel-launcher";
    text = "fuzzel --prompt '󱓞 '";
  };
  fuzzelWifi = pkgs.writeShellApplication {
    name = "fuzzel-wifi";
    text = ''iwmenu --menu custom --menu-command "fuzzel --dmenu --prompt '󱚾 ' --width=40 {password_flag:--prompt '󱚿 ' --placeholder='{placeholder}' --password --lines 0}"'';
  };
in
{
  # Fuzzel menus for app launcher, emoji picker, wifi manager, clipboard manager, etc
  home = {
    packages = with pkgs; [
      inputs.bzmenu.packages.${pkgs.system}.default
      inputs.iwmenu.packages.${pkgs.system}.default
      fuzzelActions
      fuzzelBluetooth
      fuzzelClipboard
      fuzzelEmoji
      fuzzelHistory
      fuzzelHyprshot
      fuzzelLauncher
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
  wayland.windowManager.hyprland = lib.mkIf config.wayland.windowManager.hyprland.enable {
    settings = {
      bindr = [ "$mod, $mod_L, exec, ${pkgs.procps}/bin/pkill fuzzel || fuzzel-launcher" ];
      bind = [
        ", Print, exec, fuzzel-hyprshot"
        "$mod, SPACE, exec, fuzzel-actions"
        "CTRL ALT, B, exec, fuzzel-bluetooth"
        "CTRL ALT, E, exec, fuzzel-emoji"
        "CTRL ALT, P, exec, fuzzel-clipboard"
        "CTRL ALT, R, exec, fuzzel-history"
        "CTRL ALT, W, exec, fuzzel-wifi"
      ];
    };
  };
}
