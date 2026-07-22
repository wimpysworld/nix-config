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
  yamlFormat = pkgs.formats.yaml { };
  contourConfig = yamlFormat.generate "contour.yml" {
    default_profile = "main";

    profiles.main = {
      colors = "catppuccin_mocha";
      cursor = {
        blinking = true;
        blinking_interval = 750;
        shape = "block";
      };
      font = {
        regular = {
          family = "FiraCode Nerd Font Mono";
          features = [ ];
          slant = "normal";
          weight = "regular";
        };
        size = 16;
      };
      history.limit = 65536;
      scrollbar.position = "Hidden";
    }
    // lib.optionalAttrs host.is.darwin {
      shell = "${pkgs.fish}/bin/fish";
    };

    color_schemes.catppuccin_mocha = {
      default = {
        background = getColor "base";
        foreground = getColor "text";
      };
      cursor = {
        default = getColor "rosewater";
        text = getColor "base";
      };
      normal = {
        black = getColor "surface1";
        red = getColor "red";
        green = getColor "green";
        yellow = getColor "yellow";
        blue = getColor "blue";
        magenta = getColor "pink";
        cyan = getColor "teal";
        white = getColor "subtext1";
      };
      bright = {
        black = getColor "surface2";
        red = getColor "red";
        green = getColor "green";
        yellow = getColor "yellow";
        blue = getColor "blue";
        magenta = getColor "pink";
        cyan = getColor "teal";
        white = getColor "subtext0";
      };
    };
  };
in
lib.mkIf
  (noughtyLib.isHost [
    "skrye"
    "zannah"
  ])
  {
    home.packages = [ pkgs.contour ];
    xdg.configFile."contour/contour.yml".source = contourConfig;
  }
