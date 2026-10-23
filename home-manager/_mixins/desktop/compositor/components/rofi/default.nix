{
  catppuccinPalette,
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  palette = catppuccinPalette;
  # One layout in logical pixels on every host. Rofi scales it by the
  # output scale, so the grid looks the same relative to other clients.
  appGridLayout = {
    columns = "6";
    lines = "4";
    elementIconSize = "80px";
    elementPadding = "28px 12px";
    elementSpacing = "12px";
    listviewSpacing = "8px";
    mainboxSpacing = "90px";
    mainboxPadding = "100px 225px";
    inputbarMargin = "0% 25%";
  };
  inherit (appGridLayout)
    columns
    elementIconSize
    elementPadding
    elementSpacing
    inputbarMargin
    lines
    listviewSpacing
    mainboxPadding
    mainboxSpacing
    ;

  # Read template file and substitute colours and layout values.
  templateContent = builtins.readFile ./rofi-appgrid.rasi.template;

  # Generate dynamic RASI file with substituted colours and layout values.
  rofiAppGridRasi = pkgs.writeText "rofi-appgrid.rasi" (
    lib.replaceStrings
      [
        "@text_color@"
        "@background_color@"
        "@accent_color@"
        "@surface_color@"
        "@accent_color_alpha@"
        "@selection_color@"
        "@counter_color@"
        "@listview_columns@"
        "@listview_lines@"
        "@listview_spacing@"
        "@mainbox_spacing@"
        "@mainbox_padding@"
        "@inputbar_margin@"
        "@element_spacing@"
        "@element_padding@"
        "@element_icon_size@"
      ]
      [
        (palette.mkHexA "text" palette.alpha.opaque) # text with full opacity
        (palette.mkHexA "base" palette.alpha.scrim) # full-screen scrim
        "${palette.getColor "${palette.accent}"}" # user's selected accent colour
        (palette.mkHexA "overlay0" palette.alpha.surface) # search bar surface
        (palette.mkHexA palette.accent palette.alpha.surface) # scrollbar handle
        (palette.mkHexA "surface2" palette.alpha.surface) # selected element
        (palette.mkHexA "overlay1" palette.alpha.opaque) # match counter text
        columns
        lines
        listviewSpacing
        mainboxSpacing
        mainboxPadding
        inputbarMargin
        elementSpacing
        elementPadding
        elementIconSize
      ]
      templateContent
  );
in
lib.mkIf (host.is.linux && host.is.workstation) {
  catppuccin.rofi.enable = true;
  home = {
    file."${config.xdg.configHome}/rofi/launchers/rofi-appgrid/style.rasi".source = rofiAppGridRasi;
  };

  programs = {
    rofi = {
      enable = true;
      package = pkgs.rofi;
    };
  };

}
