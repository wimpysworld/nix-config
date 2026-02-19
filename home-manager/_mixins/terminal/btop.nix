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
  catppuccin.btop.enable = config.programs.btop.enable;

  programs = {
    btop = {
      enable = true;
      package = pkgs.btop.override {
        cudaSupport = host.is.linux;
        rocmSupport = host.is.linux;
      };
    };
  };

  xdg = lib.mkIf host.is.linux {
    desktopEntries = {
      btop = {
        name = "btop++";
        noDisplay = true;
      };
    };
  };
}
