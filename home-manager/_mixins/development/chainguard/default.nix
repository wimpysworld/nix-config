# Chainguard command-line tools for platform and Wolfi development.
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
  chainctlConfigDir =
    if pkgs.stdenv.hostPlatform.isDarwin then
      "${config.home.homeDirectory}/Library/Application Support/chainctl"
    else
      "${config.xdg.configHome}/chainctl";
in
lib.mkIf (isDeveloper && isWorkHost) {
  home.activation.chainctlSkipVersionCheck = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    chainctl_config=${lib.escapeShellArg "${chainctlConfigDir}/config.yaml"}
    if [[ ! -e "$chainctl_config" && -f ${lib.escapeShellArg "${config.home.homeDirectory}/.chainguard/config.yaml"} ]]; then
      chainctl_config=${lib.escapeShellArg "${config.home.homeDirectory}/.chainguard/config.yaml"}
    fi
    if [[ ! -e "$chainctl_config" ]]; then
      run ${pkgs.coreutils}/bin/install -Dm600 /dev/null "$chainctl_config"
    fi
    run ${pkgs.yq-go}/bin/yq -i '.default.skip-version-check = true' "$chainctl_config"
  '';

  home.packages = [
    pkgs.apko
    pkgs.chainctl
    pkgs.cosign
    pkgs.melange
    pkgs.wolfictl
    pkgs.yam
  ];
}
