{ config, lib, ... }:
with lib.hm.gvariant;
{
  dconf.settings = {
    "org/gnome/desktop/background" = {
      picture-options = "zoom";
      picture-uri = "file://${config.home.homeDirectory}/Pictures/Determinate/DeterminateColorway-3840x2160.png";
    };
  };
}
