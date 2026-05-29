{
  lib,
  pkgs,
  ...
}:
{
  programs.superfile = {
    enable = true;
    package = pkgs.superfile;

    settings = {
      theme = lib.mkDefault "catppuccin-mocha";
    };
  };
}
