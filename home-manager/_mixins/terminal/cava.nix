{
  config,
  lib,
  pkgs,
  ...
}:
let
  host = config.noughty.host;
in
{
  catppuccin.cava.enable = config.programs.cava.enable;

  programs = {
    cava = {
      enable = host.is.linux;
    };
  };
}
