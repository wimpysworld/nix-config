# Chainguard command-line tools for platform and Wolfi development.
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
    pkgs.apko
    pkgs.chainctl
    pkgs.cosign
    pkgs.melange
    pkgs.wolfictl
    pkgs.yam
  ];
}
