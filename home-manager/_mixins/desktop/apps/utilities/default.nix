{
  lib,
  pkgs,
  username,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux;
  installFor = [ "martin" ];
in
lib.mkIf (builtins.elem username installFor) {
  home.packages =
    with pkgs;
    lib.optionals isLinux [
      cpu-x
      usbimager
      vaults
    ];
}
