{ lib, pkgs, ... }:
let
  inherit (pkgs.stdenv) isLinux;
in
lib.mkIf isLinux {
  home.packages = with pkgs; [
    gnome.dconf-editor
  ];

  dconf.settings = with lib.hm.gvariant; {
    "ca/desrt/dconf-editor" = {
      show-warning = false;
    };
  };
}
