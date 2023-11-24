{ lib, pkgs, ... }:
let
  inherit (pkgs.stdenv) isLinux;
in
lib.mkIf isLinux {
  home.packages = with pkgs; [
    nheko
  ];
}
