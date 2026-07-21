{
  catppuccinPalette,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  getColor = colorName: catppuccinPalette.getColor colorName;
in
lib.mkIf
  (noughtyLib.isHost [
    "skrye"
    "zannah"
  ])
  {
    home = {
      packages = [ pkgs.mlterm ];

      file = {
        ".mlterm/aafont".text = ''
          DEFAULT=FiraCode Nerd Font Mono
        '';

        ".mlterm/main".text = ''
          encoding=UTF-8
          fontsize=16
          type_engine=cairo
          use_anti_alias=true
          use_bold_font=true
          use_italic_font=true

          bg_color=${getColor "base"}
          fg_color=${getColor "text"}
          cursor_bg_color=${getColor "flamingo"}
          cursor_fg_color=${getColor "crust"}

          blink_cursor=true
          bel_mode=visual
          inner_border=2
          logsize=65536
          use_scrollbar=false
          termtype=mlterm-256color
        '';

        ".mlterm/color".text = ''
          black=${getColor "surface1"}
          red=${getColor "red"}
          green=${getColor "green"}
          yellow=${getColor "yellow"}
          blue=${getColor "blue"}
          magenta=${getColor "pink"}
          cyan=${getColor "teal"}
          white=${getColor "subtext1"}
          hl_black=${getColor "surface2"}
          hl_red=${getColor "red"}
          hl_green=${getColor "green"}
          hl_yellow=${getColor "yellow"}
          hl_blue=${getColor "blue"}
          hl_magenta=${getColor "pink"}
          hl_cyan=${getColor "teal"}
          hl_white=${getColor "subtext0"}
        '';
      };
    };
  }
