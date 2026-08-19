{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  hideWindowDecorations =
    if config.wayland.windowManager.wayfire.enable then
      false
    else if config.wayland.windowManager.hyprland.enable then
      true
    else
      false;
in
lib.mkIf host.is.workstation {
  catppuccin.ghostty.enable = config.programs.ghostty.enable;

  xdg.configFile."ghostty/shaders/winkle-cursor.glsl".source = ./winkle-cursor.glsl;

  programs.ghostty = {
    enable = true;
    enableBashIntegration = false;
    enableFishIntegration = false;
    enableZshIntegration = false;

    # nixpkgs only packages Ghostty for Linux. On Darwin, manage the app
    # outside Nix while Home Manager still writes its shared configuration.
    package = if host.is.linux then pkgs.ghostty else null;

    settings = {
      custom-shader = "shaders/winkle-cursor.glsl";
      custom-shader-animation = true;
      cursor-opacity = 0.0;
      cursor-style = "block_hollow";
      cursor-style-blink = false;
      font-family = "FiraCode Nerd Font Mono";
      font-size = 16;
      mouse-hide-while-typing = true;
      shell-integration-features = "no-cursor";
      window-decoration = if hideWindowDecorations then "none" else "auto";
    };
  };
}
