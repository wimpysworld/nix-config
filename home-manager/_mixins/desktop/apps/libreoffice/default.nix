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
lib.mkIf (lib.elem username installFor && isLinux) { home.packages = with pkgs; [ libreoffice ]; }
