{ lib, ... }:
with lib.hm.gvariant;
{
  imports = [
    ../../../services/syncthing.nix
  ];
  dconf.settings = {
    "org/gnome/desktop/background" = {
      picture-options = "zoom";
      picture-uri = "file:///home/martin/Pictures/Determinate/DeterminateColorway-3440x1440.png";
    };
  };
}
