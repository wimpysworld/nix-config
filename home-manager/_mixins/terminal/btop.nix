{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
in
{
  catppuccin.btop.enable = config.programs.btop.enable;

  programs = {
    btop = {
      enable = host.is.workstation;
      package = pkgs.btop.override {
        cudaSupport = host.is.linux && host.is.workstation;
        rocmSupport = host.is.linux && host.is.workstation;
      };
    };
  };

  xdg = lib.mkIf (host.is.linux && host.is.workstation) {
    desktopEntries = {
      btop = {
        name = "btop++";
        noDisplay = true;
      };
    };
  };
}
