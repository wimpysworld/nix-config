{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  cursorTrailShader = "wisp"; # Valid values: "boo", "tinkle", and "wisp".
  cursorTrailShaders = pkgs.fetchFromGitHub {
    owner = "hced";
    repo = "ghostty-cursor-trails";
    rev = "78f597cf66427bc382077e5e33f26981a86bb207";
    hash = "sha256-NHeCd/avyJ8SaYW8pYWcetwVroFQNokN7saiWCMu3TM=";
  };
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

  xdg.configFile = {
    "ghostty/shaders/boo-cursor.glsl".source = "${cursorTrailShaders}/boo-cursor.glsl";
    "ghostty/shaders/tinkle-cursor.glsl".source = "${cursorTrailShaders}/tinkle-cursor.glsl";
    "ghostty/shaders/wisp-cursor.glsl".source = "${cursorTrailShaders}/wisp-cursor.glsl";
  };

  programs.ghostty = {
    enable = true;
    enableBashIntegration = false;
    enableFishIntegration = false;
    enableZshIntegration = false;

    # nixpkgs only packages Ghostty for Linux. On Darwin, manage the app
    # outside Nix while Home Manager still writes its shared configuration.
    package = if host.is.linux then pkgs.ghostty else null;

    settings = {
      custom-shader = "shaders/${cursorTrailShader}-cursor.glsl";
      custom-shader-animation = "always";
      cursor-style = "block";
      cursor-style-blink = true;
      font-family = "FiraCode Nerd Font Mono";
      font-size = 16;
      mouse-hide-while-typing = true;
      shell-integration-features = "no-cursor";
      window-decoration = if hideWindowDecorations then "none" else "auto";
    };
  };
}
