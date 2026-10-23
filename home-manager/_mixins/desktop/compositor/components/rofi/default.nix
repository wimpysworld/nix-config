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
        "${palette.getColor "text"}FF" # text with full opacity
        "${palette.getColor "base"}af" # base background with transparency
        "${palette.getColor "${palette.accent}"}" # user's selected accent colour
        "${palette.getColor "overlay0"}af" # surface with transparency
        "${palette.getColor "${palette.accent}"}af" # accent colour with transparency
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
