{ lib, pkgs, ... }:
let
  inherit (pkgs.stdenv) isLinux;
in
with lib.hm.gvariant;
lib.mkIf isLinux {
  home.packages = with pkgs; [
    celluloid
  ];
  
  dconf.settings = {
    "io/github/celluloid-player/celluloid" = {
      csd-enable = false;
      dark-theme-enable = true;
    };
  };
}
