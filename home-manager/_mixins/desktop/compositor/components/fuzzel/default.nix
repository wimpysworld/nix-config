{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  inherit (host) display;
  # Fuzzel defaults to dpi-aware=auto, so on a scaled output the configured
  # point size is multiplied by the compositor scale factor. The size boost
  # exists to compensate for high-resolution panels running at scale 1.0, so
  # it is skipped when the scale already compensates, otherwise the boost
  # would double-apply. High-DPI panels keep the boost for their sizing.
  fontSize =
    if (display.primaryIsHighRes && display.primaryScale == 1.0) || display.primaryIsHighDpi then
      "30"
    else
      "18";
  fuzzelActions = pkgs.writeShellApplication {
    name = "fuzzel-actions";
    text = "fuzzel --prompt '󰌧 ' --show-actions";
  };
  fuzzelAudio = pkgs.writeShellApplication {
    name = "fuzzel-audio";
    text = ''pwmenu --launcher custom --launcher-command "fuzzel --dmenu --prompt '󰕾 '"'';
  };
  fuzzelBluetooth = pkgs.writeShellApplication {
    name = "fuzzel-bluetooth";
    text = ''bzmenu --launcher custom --launcher-command "fuzzel --dmenu --prompt '󰂯 '"'';
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
  fuzzelLauncher = pkgs.writeShellApplication {
    name = "fuzzel-launcher";
    text = "fuzzel --prompt '󱓞 '";
  };
  fuzzelWifi = pkgs.writeShellApplication {
    name = "fuzzel-wifi";
    text = ''iwmenu --launcher custom --launcher-command "fuzzel --dmenu --width=40 --prompt '󱚾 ' {password_flag:--password}"'';
  };
  compositor =
    if host.is.linux && host.is.workstation then
      lib.attrByPath [
        host.desktop
      ] null (import ../../../../../../lib/wayland-compositors.nix).compositors
    else
      null;
  sessionTarget = if compositor == null then "graphical-session.target" else compositor.sessionTarget;
in
lib.mkIf (host.is.linux && host.is.workstation) {
  catppuccin = {
    fuzzel.enable = config.programs.fuzzel.enable;
  };

  # Fuzzel menus for app launcher, emoji picker, wifi manager, clipboard manager, etc
  home = {
    packages = with pkgs; [
      bzmenu
      fuzzelActions
      fuzzelAudio
      fuzzelBluetooth
      fuzzelClipboard
      fuzzelEmoji
      fuzzelHistory
      fuzzelLauncher
      fuzzelWifi
      iwmenu
      pwmenu
      wl-clipboard
      wtype
    ];
  };
  programs = {
    fuzzel = {
      enable = true;
      package = pkgs.fuzzel.override { svgBackend = "librsvg"; };
      settings = {
        main = {
          filter-desktop = true;
          font = "FiraCode Nerd Font Mono:size=${fontSize}";
          lines = 16;
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
      systemdTargets = sessionTarget;
    };
  };
}
