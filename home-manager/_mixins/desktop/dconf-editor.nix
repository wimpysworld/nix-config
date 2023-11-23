{ lib, pkgs, ... }:
let
  inherit (pkgs.stdenv) isLinux;
in
with lib.hm.gvariant;
lib.mkIf isLinux {
  home.packages = with pkgs; [
    gnome.dconf-editor
  ];

  dconf.settings = {
    "ca/desrt/dconf-editor" = {
      show-warning = false;
    };
  };
}
