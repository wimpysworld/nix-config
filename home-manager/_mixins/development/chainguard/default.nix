# Chainguard - command-line tools for the Chainguard platform.
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
  home.packages = [
    # Also provides docker-credential-cgr, the Docker credential helper for
    # cgr.dev, which chainctl installs by symlinking itself.
    pkgs.chainctl # Command-line interface for the Chainguard platform
  ];
}
