{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  inherit (host) display;
  fuzzelCapture = pkgs.writeShellApplication {
    name = "fuzzel-capture";
    runtimeInputs = with pkgs; [
      coreutils
      fuzzel
      grim
      jq
      lswt
      notify-desktop
      pulseaudio
      satty
      slurp
      util-linux
      wl-screenrec
      wlr-randr
    ];
    text = builtins.replaceStrings [ "@wlScreenrec@" ] [ (lib.getExe pkgs.wl-screenrec) ] (
      builtins.readFile ./fuzzel-capture.sh
    );
  };
in
lib.mkIf (host.is.linux && host.is.workstation) {
  home = {
    file = {
      "${config.xdg.configHome}/satty/config.toml".text = ''
        [general]
        fullscreen = false
        early-exit = false
        initial-tool = "pointer"
        copy-command = "${pkgs.wl-clipboard}/bin/wl-copy"
        annotation-size-factor = 2
        output-filename = "${config.home.homeDirectory}/Pictures/Screenshots/screenshot-%Y%m%d-%H%M%S.png"
        save-after-copy = false
        default-hide-toolbars = false
        primary-highlighter = "block"
        disable-notifications = false

        [font]
        family = "Work Sans"
        style = "Bold"
      '';
    };
    packages = with pkgs; [
      fuzzelCapture
      grim
      lswt
      satty
      slurp
      wlr-randr
    ];
  };

  wayland.windowManager.hyprland = lib.mkIf config.wayland.windowManager.hyprland.enable {
    settings.bind = [
      ", Print, exec, fuzzel-capture"
      "ALT, Print, exec, fuzzel-capture window"
      "SHIFT, Print, exec, fuzzel-capture region"
      "CTRL ALT, Print, exec, fuzzel-capture output ${display.primaryOutput}"
    ];
  };

  wayland.windowManager.wayfire = lib.mkIf config.wayland.windowManager.wayfire.enable {
    settings.command = {
      binding_capture_menu = "KEY_PRINT";
      command_capture_menu = "fuzzel-capture";
      binding_capture_window = "<alt> KEY_PRINT";
      command_capture_window = "fuzzel-capture window";
      binding_capture_region = "<shift> KEY_PRINT";
      command_capture_region = "fuzzel-capture region";
      binding_capture_output = "<ctrl> <alt> KEY_PRINT";
      command_capture_output = "fuzzel-capture output ${display.primaryOutput}";
    };
  };
}
