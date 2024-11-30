{
  config,
  lib,
  pkgs,
  ...
}:
{
  # hyprshot is a screenshot grabber and satty is a screenshot editor
  # This config provides comprehensive screenshot functionality for hyprland
  home = {
    file = {
      "${config.xdg.configHome}/satty/config.toml".text = ''
        [general]
        # Start Satty in fullscreen mode
        fullscreen = false
        # Exit directly after copy/save action
        early-exit = false
        # Select the tool on startup [possible values: pointer, crop, line, arrow, rectangle, text, marker, blur, brush]
        initial-tool = "pointer"
        # Configure the command to be called on copy, for example `wl-copy`
        copy-command = "${pkgs.wl-clipboard}/bin/wl-copy"
        # Increase or decrease the size of the annotations
        annotation-size-factor = 2
        # Filename to use for saving action: https://docs.rs/chrono/latest/chrono/format/strftime/index.html
        output-filename = "${config.home.homeDirectory}/Pictures/Screenshots/screenshot-%Y%m%d-%H%M%S.png"
        save-after-copy = false
        default-hide-toolbars = false
        # The primary highlighter: block, freehand
        primary-highlighter = "block"
        disable-notifications = false

        # Font to use for text annotations
        [font]
        family = "Work Sans"
        style = "Bold"
      '';
    };
    packages = with pkgs; [
      hyprshot        # screenshot grabber
      satty           # screenshot editor
    ];
  };
  wayland.windowManager.hyprland = {
    settings = {
      bind = [
        ", Print, exec, ${lib.getExe pkgs.hyprshot} --mode output --raw | ${lib.getExe pkgs.satty} --filename -"
        "ALT, Print, exec, ${lib.getExe pkgs.hyprshot} --mode window --raw | ${lib.getExe pkgs.satty} --filename -"
        "SHIFT, Print, exec, ${lib.getExe pkgs.hyprshot} --mode region --raw | ${lib.getExe pkgs.satty} --filename -"
        "CTRL ALT, Print, exec, ${lib.getExe pkgs.hyprshot} --mode active --raw | ${lib.getExe pkgs.satty} --filename -"
      ];
    };
  };
}
