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
  gws = pkgs.writeShellApplication {
    name = "gws";
    runtimeInputs = [ pkgs.coreutils ];
    text =
      lib.replaceStrings
        [ "@gcloud@" "@gws@" ]
        [ (lib.getExe pkgs.google-cloud-sdk) (lib.getExe pkgs.gws) ]
        (builtins.readFile ./gws.sh);
  };
in
lib.mkIf (isDeveloper && isWorkHost) {
  home.packages = [
    pkgs.google-cloud-sdk
    gws
    pkgs.jq
  ];
  home.sessionVariables.GOOGLE_WORKSPACE_CLI_CONFIG_DIR = "${config.xdg.configHome}/gws";
}
