{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;

  # Skeleton mixin: installs the Moltis binary only on a tagged Linux
  # developer host. Configuration, services, and assistant projection
  # arrive in later cohort children.
  isMartin = noughtyLib.isUser [ "martin" ];
  moltisEnabled = isMartin && host.is.linux && noughtyLib.hostHasTag "moltis";
in
{
  config = lib.mkIf moltisEnabled {
    home.packages = [ pkgs.moltis ];
  };
}
