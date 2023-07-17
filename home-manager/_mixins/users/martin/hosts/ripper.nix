{ lib, ... }:
with lib.hm.gvariant;
{
  imports = [
    ../../../services/deckmaster.nix
    ../../../services/maestral.nix
    ../../../services/mpris-proxy.nix
    ../../../services/syncthing.nix
  ];
  dconf.settings = {
    "org/gnome/desktop/background" = {
      picture-options = "zoom";
      picture-uri = "file:///home/martin/Pictures/Determinate/DeterminateColorway-2560x1440.png";
    };
  };
}
