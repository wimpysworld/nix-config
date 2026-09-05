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
in
lib.mkIf
  (
    host.is.linux
    && host.is.workstation
    && noughtyLib.isHost [
      "skrye"
      "zannah"
    ]
  )
  {
    home.packages = [ pkgs.blackbox-terminal ];

    dconf.settings."com/raggesilver/BlackBox" = {
      font = "FiraCode Nerd Font Mono 16";
      style-preference = lib.hm.gvariant.mkUint32 2;
      theme-dark = "Catppuccin Mocha";
      theme-light = "Catppuccin Mocha";
      cursor-blink-mode = lib.hm.gvariant.mkUint32 1;
      cursor-shape = lib.hm.gvariant.mkUint32 0;
      terminal-bell = false;
      show-scrollbars = false;
      scrollback-mode = lib.hm.gvariant.mkUint32 0;
      scrollback-lines = lib.hm.gvariant.mkUint32 65536;
    };

    xdg.dataFile."blackbox/schemes/catppuccin-mocha.json".text = builtins.toJSON {
      name = "Catppuccin Mocha";
      background-color = getColor "base";
      foreground-color = getColor "text";
      palette = map getColor [
        "surface1"
        "red"
        "green"
        "yellow"
        "blue"
        "pink"
        "teal"
        "subtext1"
        "surface2"
        "red"
        "green"
        "yellow"
        "blue"
        "pink"
        "teal"
        "subtext0"
      ];
    };
  }
