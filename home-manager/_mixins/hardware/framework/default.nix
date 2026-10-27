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
lib.mkIf (host.is.linux && noughtyLib.hostHasTag "framework") {
  home.packages = with pkgs; [
    framework-tool
    framework-tool-tui
  ];
}
