{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  compositor =
    if host.is.linux && host.is.workstation then
      lib.attrByPath [ host.desktop ] null (import ../../../../../lib/wayland-compositors.nix).compositors
    else
      null;
  hideWindowDecorations = compositor != null && !compositor.capabilities.clientSideDecorations;
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
