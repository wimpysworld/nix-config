{
  config,
  lib,
  pkgs,
  ...
}:
let
  rofiAppGrid = pkgs.writeShellApplication {
    name = "rofi-appgrid";
    runtimeInputs = with pkgs; [
      rofi-wayland
    ];
    text = ''
      rofi -show drun -theme "${config.xdg.configHome}/rofi/launchers/rofi-appgrid/style.rasi"
    '';
  };
in
{
  home = {
    file."${config.xdg.configHome}/rofi/launchers/rofi-appgrid/style.rasi".source = ./rofi-appgrid.rasi;
    packages = [ rofiAppGrid ];
  };
  wayland.windowManager.hyprland = lib.mkIf config.wayland.windowManager.hyprland.enable {
    settings = {
      bindr = [
        "$mod, $mod_L, exec, ${pkgs.procps}/bin/pkill rofi || ${lib.getExe rofiAppGrid}"
      ];
    };
  };
}
