{
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "martin" ];
  inherit (pkgs.stdenv) isDarwin isLinux;
in
lib.mkIf (lib.elem username installFor) {
  home.packages = with pkgs; lib.optionals isLinux [
    vaults
  ];
}
