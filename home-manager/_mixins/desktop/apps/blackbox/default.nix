{ lib, pkgs, ... }:
let
  inherit (pkgs.stdenv) isLinux;
in
lib.mkIf isLinux {
  dconf.settings =
    with lib.hm.gvariant;
    lib.mkIf isLinux {
      "com/raggesilver/BlackBox" = {
        cursor-blink-mode = lib.hm.gvariant.mkUint32 1;
        cursor-shape = lib.hm.gvariant.mkUint32 0;
        easy-copy-paste = true;
        floating-controls = true;
        floating-controls-hover-area = lib.hm.gvariant.mkUint32 20;
        font = "FiraCode Nerd Font Mono Medium 13";
        pretty = true;
        remember-window-size = true;
        scrollback-lines = lib.hm.gvariant.mkUint32 10240;
        theme-dark = "Catppuccin-Mocha";
        window-height = lib.hm.gvariant.mkUint32 1150;
        window-width = lib.hm.gvariant.mkUint32 1450;
      };
    };

  home.file = {
    ".local/share/blackbox/schemes/Catppuccin-Mocha.json".text = ''
      {
        "name": "Catppuccin-Mocha",
        "comment": "Soothing pastel theme for the high-spirited!",
        "background-color": "#1E1E2E",
        "foreground-color": "#CDD6F4",
        "badge-color": "#585B70",
        "bold-color": "#585B70",
        "cursor-background-color": "#F5E0DC",
        "cursor-foreground-color": "#1E1E2E",
        "highlight-background-color": "#F5E0DC",
        "highlight-foreground-color": "#1E1E2E",
        "palette": [
          "#45475A",
          "#F38BA8",
          "#A6E3A1",
          "#F9E2AF",
          "#89B4FA",
          "#F5C2E7",
          "#94E2D5",
          "#BAC2DE",
          "#585B70",
          "#F38BA8",
          "#A6E3A1",
          "#F9E2AF",
          "#89B4FA",
          "#F5C2E7",
          "#94E2D5",
          "#A6ADC8"
        ],
        "use-badge-color": false,
        "use-bold-color": false,
        "use-cursor-color": true,
        "use-highlight-color": true,
        "use-theme-colors": false
      }
    '';
  };
  home.packages = with pkgs; [ blackbox ];
}
