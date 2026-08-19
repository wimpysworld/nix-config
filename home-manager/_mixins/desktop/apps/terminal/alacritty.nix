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
  catppuccin.alacritty.enable = config.programs.alacritty.enable;

  programs.alacritty = {
    enable = true;
    package = pkgs.alacritty-graphics;
    settings = {
      cursor = {
        blink_interval = 750;
        blink_timeout = 0;
        style = {
          blinking = "Always";
          shape = "Block";
        };
        unfocused_hollow = true;
      };
      font = {
        normal.family = "FiraCode Nerd Font Mono";
        size = 16;
      };
      scrolling.history = 65536;
      selection.save_to_clipboard = true;
      window = {
        decorations = if hideWindowDecorations then "None" else "Full";
        padding = {
          x = 2;
          y = 2;
        };
      };
    };
  };
}
