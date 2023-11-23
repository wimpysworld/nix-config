{ lib, pkgs, ... }:
let
  inherit (pkgs.stdenv) isLinux;
in
with lib.hm.gvariant;
{
  home.packages = with pkgs; [
    meld
  ];

  dconf.settings = lib.mkIf isLinux {
    "org/gnome/meld" = {
      indent-width = 4;
      insert-spaces-instead-of-tabs = true;
      highlight-current-line = true;
      show-line-numbers = true;
      prefer-dark-theme = true;
      highlight-syntax = true;
      style-scheme = "Yaru-dark";
    };
  };
}
