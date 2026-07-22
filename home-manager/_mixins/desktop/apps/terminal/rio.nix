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
  getColor = colorName: catppuccinPalette.getColor colorName;
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
    # Catppuccin's Rio module imports a system-specific source derivation. Keep
    # the native integration on Linux and define the same Mocha palette directly
    # on Darwin so Linux can evaluate Darwin Home Manager configurations.
    catppuccin.rio.enable = config.programs.rio.enable && host.is.linux;

    programs.rio = {
      enable = true;
      package = pkgs.rio;
      settings = {
        copy-on-select = true;
        enable-scroll-bar = false;
        hide-mouse-cursor-when-typing = true;
        margin = [ 2 ];
        scrollback-history-limit = 65536;
        cursor = {
          blinking = true;
          blinking-interval = 750;
          shape = "block";
        };
        fonts = {
          family = "FiraCode Nerd Font Mono";
          size = 21.333333;
        };
        window.decorations = if hideWindowDecorations then "Disabled" else "Enabled";
      }
      // lib.optionalAttrs host.is.darwin {
        colors = {
          background = getColor "base";
          foreground = getColor "text";
          black = getColor "surface1";
          red = getColor "red";
          green = getColor "green";
          yellow = getColor "yellow";
          blue = getColor "blue";
          magenta = getColor "pink";
          cyan = getColor "teal";
          white = getColor "subtext1";
          cursor = getColor "rosewater";
          tabs = getColor "base";
          tabs-foreground = getColor "text";
          tabs-active = getColor "lavender";
          tabs-active-highlight = getColor "lavender";
          tabs-active-foreground = getColor "crust";
          selection-foreground = getColor "base";
          selection-background = getColor "rosewater";
          dim-black = getColor "surface1";
          dim-red = getColor "red";
          dim-green = getColor "green";
          dim-yellow = getColor "yellow";
          dim-blue = getColor "blue";
          dim-magenta = getColor "pink";
          dim-cyan = getColor "teal";
          dim-white = getColor "subtext1";
          dim-foreground = getColor "text";
          light-black = getColor "surface2";
          light-red = getColor "red";
          light-green = getColor "green";
          light-yellow = getColor "yellow";
          light-blue = getColor "blue";
          light-magenta = getColor "pink";
          light-cyan = getColor "teal";
          light-white = getColor "subtext0";
          light-foreground = getColor "text";
        };
      };
    };
  }
