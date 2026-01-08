{
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "martin" ];
  inherit (pkgs.stdenv) isLinux;
in
lib.mkIf (builtins.elem username installFor) {
  home.packages =
    with pkgs;
    lib.optionals isLinux [
      cider
    ];
}
