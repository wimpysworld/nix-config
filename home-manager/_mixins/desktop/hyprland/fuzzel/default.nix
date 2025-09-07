{
  config,
  hostname,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  fontSize = if (hostname == "phasma" || hostname == "vader") then "30" else "18";
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
  fuzzelHyprpicker = pkgs.writeShellApplication {
    name = "fuzzel-hyprpicker";
    runtimeInputs = with pkgs; [
      hyprpicker
      notify-desktop
      wl-clipboard
    ];
    text = builtins.readFile ./fuzzel-hyprpicker.sh;
  };
  fuzzelHyprshot = pkgs.writeShellApplication {
    name = "fuzzel-hyprshot";
    runtimeInputs = with pkgs; [
      gnugrep
      hyprshot
      jq
      pulseaudio
      satty
      slurp
      wl-screenrec
    ];
    text = builtins.readFile ./fuzzel-hyprshot.sh;
  };
  fuzzelLauncher = pkgs.writeShellApplication {
    name = "fuzzel-launcher";
    text = "fuzzel --prompt '󱓞 '";
  };
  fuzzelWifi = pkgs.writeShellApplication {
    name = "fuzzel-wifi";
    text = ''iwmenu --launcher custom --launcher-command "fuzzel --dmenu --width=40 --prompt '󱚾 ' {password_flag:--password}"'';
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
      fuzzelHyprpicker
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
      package = (pkgs.fuzzel.override { svgBackend = "librsvg"; });
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
      systemdTargets = "hyprland-session.target";
    };
  };
  wayland.windowManager.hyprland = lib.mkIf config.wayland.windowManager.hyprland.enable {
    settings = {
      bind = [
        ", Print, exec, fuzzel-hyprshot"
        "CTRL ALT, SPACE, exec, hypr-activity-menu"
        "CTRL ALT, B, exec, fuzzel-bluetooth"
        "CTRL ALT, E, exec, fuzzel-emoji"
        "CTRL ALT, K, exec, fuzzel-hyprpicker"
        "CTRL ALT, P, exec, fuzzel-clipboard"
        "CTRL ALT, R, exec, fuzzel-history"
        "CTRL ALT, W, exec, fuzzel-wifi"
      ];
    };
  };
}
