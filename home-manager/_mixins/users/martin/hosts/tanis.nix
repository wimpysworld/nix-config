{ config, lib, ... }:
{
  dconf.settings = with lib.hm.gvariant; {
    "org/gnome/desktop/background" = {
      picture-options = "zoom";
      picture-uri = "file://${config.home.homeDirectory}/Pictures/Determinate/DeterminateColorway-1920x1200.png";
    };
  };
}
