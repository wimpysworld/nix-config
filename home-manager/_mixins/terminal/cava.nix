{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux;
in
{
  catppuccin.cava.enable = config.programs.cava.enable;

  programs = {
    cava = {
      enable = isLinux;
    };
  };
}
