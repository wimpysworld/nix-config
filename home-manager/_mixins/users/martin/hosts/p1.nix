{ lib, ... }:
with lib.hm.gvariant;
{
  imports = [
    ../../../services/mpris-proxy.nix
    ../../../services/syncthing.nix
  ];
  dconf.settings = {
    "org/gnome/desktop/background" = {
      picture-options = "zoom";
      picture-uri = "file:///home/martin/Pictures/Determinate/DeterminateColorway-3840x2160.png";
    };
  };
}
