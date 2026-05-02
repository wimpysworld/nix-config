{
  catppuccinPalette,
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  inherit (host) display;
  palette = catppuccinPalette;
  desktopLayout = {
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
  laptopLayout = {
    columns = "5";
    lines = "4";
    elementIconSize = "76px";
    elementPadding = "24px 10px";
    elementSpacing = "10px";
    listviewSpacing = "8px";
    mainboxSpacing = "82px";
    mainboxPadding = "92px 200px";
    inputbarMargin = "0% 22%";
  };
  compactLaptopLayout = {
    columns = "5";
    lines = "3";
    elementIconSize = "72px";
    elementPadding = "24px 10px";
    elementSpacing = "10px";
    listviewSpacing = "8px";
    mainboxSpacing = "76px";
    mainboxPadding = "88px 190px";
    inputbarMargin = "0% 22%";
  };
  appGridLayout =
    if host.is.laptop && (display.primaryHeight <= 1080 || display.primaryIsHighDpi) then
      compactLaptopLayout
    else if host.is.laptop then
      laptopLayout
    else
      desktopLayout;
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

  wayland.windowManager = {
    hyprland = lib.mkIf config.wayland.windowManager.hyprland.enable {
      settings = {
        bindr = [
          "$mod, $mod_L, exec, ${pkgs.procps}/bin/pkill rofi || rofi -theme ${config.xdg.configHome}/rofi/launchers/rofi-appgrid/style.rasi -show drun"
        ];
      };
    };
    wayfire = lib.mkIf config.wayland.windowManager.wayfire.enable {
      settings = {
        autostart = {
          rofi = false;
        };
        command = {
          # Super key toggles rofi launcher
          binding_launcher = "<super>";
          command_launcher = "${pkgs.procps}/bin/pkill rofi || rofi -theme ${config.xdg.configHome}/rofi/launchers/rofi-appgrid/style.rasi -show drun";
        };
      };
    };
  };
}
