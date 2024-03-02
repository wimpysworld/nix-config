{ config, lib, pkgs, username, ... }:
{
  imports = [
    ../../desktop/chatterino2.nix
    ../../desktop/discord.nix
    ../../desktop/gitkraken.nix
    #../../desktop/localsend.nix
    ../../desktop/meld.nix
    ../../desktop/rhythmbox.nix
    ../../desktop/sakura.nix
    ../../desktop/vscode.nix
  ];

  # User specific dconf settings; only intended as override for NixOS dconf profile user database
  dconf.settings = with lib.hm.gvariant; {
    "com/gexperts/Tilix" = {
      app-title = "\${appName}: \${directory}";
      paste-strip-trailing-whitespace = true;
      prompt-on-close = true;
      quake-hide-lose-focus = true;
      quake-specific-monitor = mkInt32 0;
      session-name = "\${id}";
      terminal-title-show-when-single = true;
      terminal-title-style = "none";
      use-tabs = true;
      window-style = "normal";
    };

    "com/gexperts/Tilix/keybindings" = {
      win-view-sidebar = "<Primary>F12";
    };

    "com/gexperts/Tilix/profiles" = {
      default = "d1def387-a465-4497-81bc-b8b2de782b2d";
      list = [ "d1def387-a465-4497-81bc-b8b2de782b2d" ];
    };

    "com/gexperts/Tilix/profiles/d1def387-a465-4497-81bc-b8b2de782b2d" = {
      background-color = "#121212121414";
      badge-color = "#E6E66D6DFFFF";
      badge-color-set = true;
      badge-font = "FiraCode Nerd Font Mono 12";
      #badge-text = "\${columns}x\${rows}";
      badge-text = "";
      badge-use-system-font = false;
      bold-color = "#C8C8C8C8C8C8";
      bold-color-set = true;
      bold-is-bright = false;
      cell-height-scale = mkDouble 1.0;
      cell-width-scale = mkDouble 1.0;
      cursor-background-color = "#FFFFB6B63838";
      cursor-blink-mode = "on";
      cursor-colors-set = true;
      cursor-foreground-color = "#FFFFB6B63838";
      default-size-columns = mkInt32 132;
      default-size-rows = mkInt32 50;
      draw-margin = mkInt32 80;
      font = "FiraCode Nerd Font Medium 12";
      foreground-color = "#C8C8C8C8C8C8";
      highlight-background-color = "#1E1E1E1E2020";
      highlight-colors-set = false;
      highlight-foreground-color = "#C8C8C8C8C8C8";
      palette = [ "#121212121414" "#D6D62B2B2B2B" "#4141DDDD7575" "#FFFFB6B63838" "#2828A9A9FFFF" "#E6E66D6DFFFF" "#1414E5E5D3D3" "#C8C8C8C8C8C8" "#434343434545" "#DEDE56565656" "#A1A1EEEEBBBB" "#FFFFC5C56060" "#9494D4D4FFFF" "#F2F2B6B6FFFF" "#A0A0F5F5EDED" "#E9E9E9E9E9E9" ];
      scrollback-unlimited = true;
      terminal-title = "";
      use-system-font = true;
      use-theme-colors = false;
      visible-name = "Bearded Dark Vivid";
    };
  };
}
