{
  catppuccinPalette,
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  palette = catppuccinPalette;
  catppuccinFuzzel = config.catppuccin.fuzzel;
  # Home Manager writes [colors] before [main], so the Catppuccin include in
  # [main] overrides any colour set in settings. This file includes the
  # Catppuccin theme first, then sets the background at the surface alpha.
  fuzzelTheme = pkgs.writeText "fuzzel-theme.ini" ''
    include=${config.catppuccin.sources.fuzzel}/catppuccin-${catppuccinFuzzel.flavor}/${catppuccinFuzzel.accent}.ini

    [colors]
    background=${lib.removePrefix "#" (palette.mkHexA "base" palette.alpha.surface)}
  '';
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
  fuzzelControlCenter = pkgs.writeShellApplication {
    name = "fuzzel-control-center";
    runtimeInputs = with pkgs; [
      cpu-x
      formatter
      gnome-disk-utility
      gnome-firmware
      networkmanagerapplet
      overskride
      piper
      pwvucontrol
      system-config-printer
      usbimager
      util-linux
      (import ../kanshi/wdisplays.nix { inherit config pkgs; }).package
    ];
    text = builtins.readFile ./fuzzel-control-center.sh;
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
  fuzzelNotes = pkgs.writeShellApplication {
    name = "fuzzel-notes";
    runtimeInputs = with pkgs; [
      coreutils
      config.programs.fuzzel.package
      jq
      util-linux
      zk
    ];
    runtimeEnv.MANUSCRIPT = lib.getExe pkgs.manuscript;
    text = builtins.readFile ./fuzzel-notes.sh;
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
    packages =
      with pkgs;
      [
        bzmenu
        fuzzelActions
        fuzzelAudio
        fuzzelBluetooth
        fuzzelClipboard
        fuzzelControlCenter
        fuzzelEmoji
        fuzzelHistory
        fuzzelLauncher
        fuzzelNotes
        pwmenu
        wl-clipboard
        wtype
      ]
      ++ lib.optionals host.network.wifi [
        fuzzelWifi
        iwmenu
      ];
  };
  programs = {
    fuzzel = {
      enable = true;
      package = pkgs.fuzzel.override { svgBackend = "librsvg"; };
      settings = {
        main = {
          include = lib.mkForce "${fuzzelTheme}";
          filter-desktop = true;
          # One size everywhere. With dpi-aware=no, Fuzzel multiplies the point
          # size by the output's scale factor, so each display's chosen scale
          # sets the apparent size, including scales that wdisplays changes.
          # The default, auto, switches to physical DPI when every output is
          # at scale 1, which makes the size differ between hosts.
          dpi-aware = "no";
          font = "FiraCode Nerd Font Mono:size=38";
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
