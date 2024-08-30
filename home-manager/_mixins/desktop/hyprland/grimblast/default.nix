{
  config,
  lib,
  pkgs,
  ...
}:
{
  # grimblast is a screenshot grabber and swappy is a screenshot editor
  # This config provide comprehensive screenshot functionality for hyprland
  home = {
    file = {
      "${config.xdg.configHome}/swappy/config".text = ''
        [Default]
        save_dir=${config.home.homeDirectory}/Pictures/Screenshots
        save_filename_format=screenshot-%Y%m%d-%H%M%S.png
        text_size=50
        text_font=Work Sans Bold
        early_exit=true
      '';
    };
    packages = with pkgs; [
      grimblast       # screenshot grabber
      swappy          # screenshot editor
    ];
  };
  wayland.windowManager.hyprland = {
    settings = {
      bind = [
        ", Print, exec, ${lib.getExe pkgs.grimblast} save screen - | ${lib.getExe pkgs.swappy} -f -"
        "SHIFT, Print, exec, ${lib.getExe pkgs.grimblast} save area - | ${lib.getExe pkgs.swappy} -f -"
        "CTRL ALT, Print, exec, ${lib.getExe pkgs.grimblast} save active - | ${lib.getExe pkgs.swappy} -f -"
        "CTRL, Print, exec, ${lib.getExe pkgs.grimblast} save output - | ${lib.getExe pkgs.swappy} -f -"
      ];
    };
  };
}
