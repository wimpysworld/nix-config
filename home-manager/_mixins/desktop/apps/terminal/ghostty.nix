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

  xdg.configFile."ghostty/shaders/mochi-ghostty.glsl".source =
    if host.is.linux then
      pkgs.writeText "mochi-ghostty.glsl" (
        "#define MOCHI_KEY_REPEAT_RATE ${toString config.noughty.user.keyboard.repeatRate}.0\n"
        + builtins.readFile ./mochi-ghostty.glsl
      )
    else
      ./mochi-ghostty.glsl;

  programs.ghostty = {
    enable = true;
    enableBashIntegration = false;
    enableFishIntegration = false;
    enableZshIntegration = false;

    # Darwin installs Ghostty through Homebrew and shares this configuration.
    package = if host.is.linux then pkgs.ghostty else null;

    settings = {
      custom-shader = "shaders/mochi-ghostty.glsl";
      custom-shader-animation = true;
      cursor-opacity = 0.0;
      cursor-style = "block_hollow";
      cursor-style-blink = false;
      font-family = "FiraCode Nerd Font Mono";
      font-size = 16;
      mouse-hide-while-typing = true;
      shell-integration-features = "no-cursor";
      split-inherit-working-directory = true;
      tab-inherit-working-directory = true;
      window-decoration = if hideWindowDecorations then "none" else "auto";
      window-inherit-working-directory = false;
      working-directory = "home";
    };
  };
}
