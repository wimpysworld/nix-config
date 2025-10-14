{
  catppuccinPalette,
  config,
  lib,
  pkgs,
  ...
}:
let
  # Read template file and substitute colors
  templateContent = builtins.readFile ./rofi-appgrid.rasi.template;

  # Generate dynamic RASI file with substituted colors
  rofiAppGridRasi = pkgs.writeText "rofi-appgrid.rasi" (
    lib.replaceStrings
      [ "@text_color@" "@background_color@" "@accent_color@" "@surface_color@" "@accent_color_alpha@" ]
      [
        "${catppuccinPalette.getColor "text"}FF" # text with full opacity
        "${catppuccinPalette.getColor "base"}af" # base background with transparency
        "${catppuccinPalette.getColor "${catppuccinPalette.accent}"}" # user's selected accent color
        "${catppuccinPalette.getColor "overlay0"}af" # surface with transparency
        "${catppuccinPalette.getColor "${catppuccinPalette.accent}"}af" # accent color with transparency
      ]
      templateContent
  );
in
{
  catppuccin.rofi.enable = true;
  home = {
    file."${config.xdg.configHome}/rofi/launchers/rofi-appgrid/style.rasi".source = rofiAppGridRasi;
  };

  programs = {
    rofi = {
      enable = true;
      package = pkgs.unstable.rofi;
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
