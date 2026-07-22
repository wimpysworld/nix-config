{
  config,
  lib,
  noughtyLib,
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
lib.mkIf
  (noughtyLib.isHost [
    "skrye"
    "zannah"
  ])
  {
    catppuccin.ghostty.enable = config.programs.ghostty.enable;

    programs.ghostty = {
      enable = true;
      enableBashIntegration = false;
      enableFishIntegration = false;
      enableZshIntegration = false;

      # nixpkgs only packages Ghostty for Linux. On Darwin, manage the app
      # outside Nix while Home Manager still writes its shared configuration.
      package = if host.is.linux then pkgs.ghostty else null;

      settings = {
        cursor-style = "block";
        cursor-style-blink = true;
        font-family = "FiraCode Nerd Font Mono";
        font-size = 16;
        mouse-hide-while-typing = true;
        window-decoration = if hideWindowDecorations then "none" else "auto";
      };
    };
  }
