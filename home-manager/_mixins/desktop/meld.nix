{ lib, pkgs, ... }:
let
  inherit (pkgs.stdenv) isLinux;
in
{
  home.packages = with pkgs; [
    meld
  ];

  dconf.settings = with lib.hm.gvariant; lib.mkIf isLinux {
    "org/gnome/meld" = {
      indent-width = mkInt32 4;
      insert-spaces-instead-of-tabs = true;
      highlight-current-line = true;
      show-line-numbers = true;
      prefer-dark-theme = true;
      highlight-syntax = true;
      style-scheme = "oblivion";
    };
  };
}
