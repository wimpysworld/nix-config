# Google Cloud command-line tools.
{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  isDeveloper = noughtyLib.userHasTag "developer";
  isWorkHost = noughtyLib.hostHasTag "cg";
in
lib.mkIf (isDeveloper && isWorkHost) {
  home.packages = [
    pkgs.google-cloud-sdk
    pkgs.gws
    pkgs.jq
  ];
  home.sessionVariables.GOOGLE_WORKSPACE_CLI_CONFIG_DIR = "${config.xdg.configHome}/gws";
}
