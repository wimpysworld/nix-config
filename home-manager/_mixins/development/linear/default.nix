# Linear - issue tracking for the Linear service.
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
  home = {
    # Nixpkgs builds the Linear desktop application for Darwin only.
    packages = lib.optional host.is.darwin pkgs.linear;
  };
}
