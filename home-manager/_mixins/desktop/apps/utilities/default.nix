{
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux;
in
lib.mkIf (noughtyLib.isUser [ "martin" ]) {
  home.packages =
    with pkgs;
    lib.optionals isLinux [
      cpu-x
      usbimager
      vaults
    ];
}
