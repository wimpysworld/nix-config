{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux;
in
lib.mkIf isLinux {
  # User specific dconf settings; only intended as override for NixOS dconf profile user database
  dconf.settings =
    with lib.hm.gvariant;
    lib.mkIf isLinux {
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
        background-color = "#1E1E2E";
        badge-color-set = false;
        bold-color-set = false;
        cell-height-scale = mkDouble 1.0;
        cell-width-scale = mkDouble 1.0;
        cursor-background-color = "#F5E0DC";
        cursor-blink-mode = "on";
        cursor-colors-set = true;
        cursor-foreground-color = "#1E1E2E";
        default-size-columns = mkInt32 132;
        default-size-rows = mkInt32 50;
        draw-margin = mkInt32 80;
        font = "FiraCode Nerd Font Mono Medium 13";
        foreground-color = "#CDD6F4";
        highlight-background-color = "#F5E0DC";
        highlight-colors-set = true;
        highlight-foreground-color = "#1E1E2E";
        palette = [
          "#BAC2DE"
          "#F38BA8"
          "#A6E3A1"
          "#F9E2AF"
          "#89B4FA"
          "#F5C2E7"
          "#94E2D5"
          "#585B70"
          "#A6ADC8"
          "#F38BA8"
          "#A6E3A1"
          "#F9E2AF"
          "#89B4FA"
          "#F5C2E7"
          "#94E2D5"
          "#45475A"
        ];
        scrollback-unlimited = true;
        terminal-title = "";
        use-system-font = true;
        use-theme-colors = false;
        visible-name = "Default";
      };
    };

  home.file = {
    "${config.xdg.configHome}/tilix/schemes/Catppuccin-Mocha.json".text = ''
      {
        "name": "Catppuccin Mocha",
        "comment": "Soothing pastel theme for Tilix",
        "background-color": "#1e1e2e",
        "foreground-color": "#cdd6f4",
        "badge-color": "#585b70",
        "bold-color": "#585b70",
        "cursor-background-color": "#f5e0dc",
        "cursor-foreground-color": "#1e1e2e",
        "highlight-background-color": "#f5e0dc",
        "highlight-foreground-color": "#1e1e2e",
        "palette": [
          "#bac2de",
          "#f38ba8",
          "#a6e3a1",
          "#f9e2af",
          "#89b4fa",
          "#f5c2e7",
          "#94e2d5",
          "#585b70",
          "#a6adc8",
          "#f38ba8",
          "#a6e3a1",
          "#f9e2af",
          "#89b4fa",
          "#f5c2e7",
          "#94e2d5",
          "#45475a"
        ],
        "use-badge-color": false,
        "use-bold-color": false,
        "use-cursor-color": true,
        "use-highlight-color": true,
        "use-theme-colors": false
      }
    '';
  };
  home.packages = with pkgs; [ tilix ];
}
