{
  catppuccinPalette,
  config,
  lib,
  ...
}:
let
  inherit (config.noughty) host;
  palette = catppuccinPalette;
in
lib.mkIf (host.is.linux && host.is.workstation) {
  # avizo is an osd notification daemon for audio and backlight
  # avizo provides volumectl and lightctl for controlling audio and backlight
  services = {
    avizo = {
      enable = true;
      settings = {
        default = {
          background = palette.mkRgba "base" "0.8";
          bar-bg-color = palette.mkRgba "surface2" "0.9";
          bar-fg-color = palette.mkRgba "blue" "0.9";
          border-color = palette.mkRgba "blue" "1";
          border-width = 1;
          block-count = 20;
          block-height = 16;
          block-spacing = 4;
          image-opacity = 0.9;
          padding = 32;
          time = 2;
          fade-in = 0.5;
          fade-out = 0.75;
          width = 480;
          height = 240;
          y-offset = 0.75;
        };
      };
    };
  };
}
