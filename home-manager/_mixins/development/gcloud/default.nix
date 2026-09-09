# Google Cloud command-line tools.
{
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
    (pkgs.google-cloud-sdk.withExtraComponents (with pkgs.google-cloud-sdk.components; [ beta ]))
  ];
}
