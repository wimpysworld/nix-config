{
  lib,
  pkgs,
  ...
}:
{
  programs.superfile = {
    enable = true;
    package = pkgs.unstable.superfile;

    settings = {
      theme = lib.mkDefault "catppuccin-mocha";
    };
  };
}
