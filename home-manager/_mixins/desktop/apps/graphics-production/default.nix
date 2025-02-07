{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux;
in
lib.mkIf (isLinux) {
  home.file = {
    "${config.xdg.configHome}/GIMP/2.10/themes/Catppuccin-Gimp-Theme" = {
      source = ./Catppuccin-Gimp-Theme;
      recursive = true;
    };
  };

  home.packages = with pkgs; [
    gimp
  ];
}
