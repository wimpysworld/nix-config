{
  lib,
  pkgs,
  platform,
  username,
  ...
}:
let
  installFor = [ "martin" ];
  inherit (pkgs.stdenv) isLinux;
in
lib.mkIf (lib.elem username installFor) {
  home = lib.mkIf isLinux {
    packages = [ pkgs.heynote ];
  };
}
