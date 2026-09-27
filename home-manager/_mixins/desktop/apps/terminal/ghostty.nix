{
  config,
  lib,
  noughtyLib,
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
  # The mochi shader draws its own cursor, so only Strix Halo hosts load it.
  useMochiShader = noughtyLib.hostHasTag "strix-halo";
in
lib.mkIf host.is.workstation {
  catppuccin.ghostty.enable = config.programs.ghostty.enable;

  xdg.configFile."ghostty/shaders/mochi-ghostty.glsl" = lib.mkIf useMochiShader {
    source =
      if host.is.linux then
        pkgs.writeText "mochi-ghostty.glsl" (
          "#define MOCHI_KEY_REPEAT_RATE ${toString config.noughty.user.keyboard.repeatRate}.0\n"
          + builtins.readFile ./mochi-ghostty.glsl
        )
      else
        ./mochi-ghostty.glsl;
  };

  programs.ghostty = {
    enable = true;
    enableBashIntegration = false;
    enableFishIntegration = false;
    enableZshIntegration = false;

    # Darwin installs Ghostty through Homebrew and shares this configuration.
    package = if host.is.linux then pkgs.ghostty else null;

    settings = {
      font-family = "FiraCode Nerd Font Mono";
      font-size = 16;
      mouse-hide-while-typing = true;
      split-inherit-working-directory = true;
      tab-inherit-working-directory = true;
      window-decoration = if hideWindowDecorations then "none" else "auto";
      window-inherit-working-directory = false;
      working-directory = "home";

      # Herdr plugin icon fonts use Private Use Area glyphs, which do not fall
      # back like ordinary characters. Herdr Agent Icons Max is installed to
      # the user font directory by herdr-agent-quota's configure action.
      # Ghostty accepts repeated keys, so the two range mappings ride a list.
      font-codepoint-map = [
        "U+E1A0-U+E1B6=\"Herdr Agent Icons Max\""
        "U+E1C0-U+E1C5=\"Herdr Agent Icons Max\""
      ];
    }
    // lib.optionalAttrs useMochiShader {
      # Hide the native cursor because the shader draws its replacement.
      custom-shader = "shaders/mochi-ghostty.glsl";
      custom-shader-animation = true;
      cursor-opacity = 0.0;
      cursor-style = "block_hollow";
      cursor-style-blink = false;
      shell-integration-features = "no-cursor";
    };
  };
}
