{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
in
lib.mkIf (noughtyLib.isUser [ "martin" ] && host.is.workstation) {
  home = {
    packages = [
      pkgs.heynote
      pkgs.unstable.notesnook
    ];
  };
}
