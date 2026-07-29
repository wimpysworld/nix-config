# Chainguard - command-line tools for the Chainguard platform and Wolfi.
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
    # Also provides docker-credential-cgr, the Docker credential helper for
    # cgr.dev, which chainctl installs by symlinking itself.
    pkgs.chainctl # Command-line interface for the Chainguard platform
    pkgs.wolfictl # Command-line interface for the Wolfi OSS project
  ];
}
