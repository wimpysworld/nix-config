{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux;
in
lib.mkIf (isLinux) {
  home.packages = with pkgs; [
    gimp3
  ];
}
