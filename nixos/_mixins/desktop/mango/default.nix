{
  config,
  lib,
  noughtyLib,
  ...
}:
let
  inherit (config.noughty) host;
in
{
  config = lib.mkIf (host.desktop == "mango") {
    environment.sessionVariables = {
      WLR_NO_HARDWARE_CURSORS = lib.mkIf (noughtyLib.hostHasTag "reframe") 1;
    };
  };
}
