# Chainguard command-line tools for platform and Wolfi development.
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
    pkgs.apko
    pkgs.chainctl
    pkgs.cosign
    pkgs.melange
    pkgs.wolfictl
    pkgs.yam
  ];
}
