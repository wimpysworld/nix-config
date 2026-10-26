{
  catppuccinPalette,
  config,
  lib,
  noughtyLib,
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
    # Copy to the regular clipboard, so that Ctrl+V pastes the entry. Stop when
    # the picker is cancelled, so that an empty selection never clears the
    # clipboard.
    text = ''
      selection=$(cliphist list | fuzzel --dmenu --prompt '󱘢 ' --width 56) || exit 0
      [ -n "$selection" ] || exit 0
      printf '%s\n' "$selection" | cliphist decode | wl-copy --trim-newline
    '';
  };
  fuzzelConnections = import ./connections.nix {
    inherit pkgs;
    fuzzel = config.programs.fuzzel.package;
    configFile = "${config.xdg.configHome}/fuzzel/fuzzel.ini";
    inherit (config.noughty.network) tailNet;
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
  fuzzelEmoji = import ./emoji.nix {
    inherit pkgs;
    fuzzel = config.programs.fuzzel.package;
    configFile = "${config.xdg.configHome}/fuzzel/fuzzel.ini";
  };
  fuzzelHistory = pkgs.writeShellApplication {
    name = "fuzzel-history";
    # Copy to the regular clipboard, and stop when the picker is cancelled,
    # as the clipboard picker does.
    text = ''
      selection=$($SHELL -c history | uniq | fuzzel --dmenu --prompt '󱆃 ' --width 56) || exit 0
      [ -n "$selection" ] || exit 0
      printf '%s' "$selection" | wl-copy --trim-newline
    '';
  };
  fuzzelKeybindings = import ./keybindings.nix {
    inherit pkgs;
    fuzzel = config.programs.fuzzel.package;
    configFile = "${config.xdg.configHome}/fuzzel/fuzzel.ini";
    entries = config.compositor.keybindingHelp.entries;
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
      ++ lib.optional (compositor != null && config.programs.fuzzel.enable) fuzzelKeybindings
      ++ lib.optional (noughtyLib.isUser [ "martin" ]) fuzzelConnections
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
