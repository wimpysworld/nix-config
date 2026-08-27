# Google Cloud command-line tools.
{
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  isDeveloper = noughtyLib.userHasTag "developer";
  isPolicyHost = noughtyLib.hostHasTag "policy";
in
lib.mkIf (isDeveloper && isPolicyHost) {
  home.packages = [
    (pkgs.google-cloud-sdk.withExtraComponents (with pkgs.google-cloud-sdk.components; [ beta ]))
  ];
}
