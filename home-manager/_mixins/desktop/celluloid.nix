{ lib, pkgs, ... }:
with lib.hm.gvariant;
{
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
