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
  catppuccin.btop.enable = config.programs.btop.enable;

  programs = {
    btop = {
      enable = true;
      package = pkgs.btop.override {
        cudaSupport = isLinux;
        rocmSupport = isLinux;
      };
    };
  };

  xdg = lib.mkIf isLinux {
    desktopEntries = {
      btop = {
        name = "btop++";
        noDisplay = true;
      };
    };
  };
}
