{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  host = config.noughty.host;
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
