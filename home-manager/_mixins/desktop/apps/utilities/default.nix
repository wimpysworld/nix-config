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
lib.mkIf (noughtyLib.isUser [ "martin" ]) {
  home.packages =
    with pkgs;
    lib.optionals host.is.linux [
      cpu-x
      usbimager
      vaults
    ];
}
