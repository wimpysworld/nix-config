# Linear - issue tracking for the Linear service.
#
# Upstream linear-tui only accepts its built-in theme names, so its
# configuration remains unmanaged here.
{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  isDeveloper = noughtyLib.userHasTag "developer";
  isWorkstationDeveloper = isDeveloper && host.is.workstation;
in
lib.mkIf isWorkstationDeveloper {
  xdg.configFile."linear-term/config.yaml".text = ''
    appearance:
      theme: catppuccin-mocha
  '';

  home = {
    packages = [
      pkgs.linear-term # Terminal user interface for Linear
      pkgs.linear-tui # Terminal user interface for Linear
    ]
    # Nixpkgs builds the Linear desktop application for Darwin only.
    ++ lib.optional host.is.darwin pkgs.linear;
  };
}
