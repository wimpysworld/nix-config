{ lib, ... }:
with lib.hm.gvariant;
{
  dconf.settings = {
    "io/github/celluloid-player/celluloid" = {
      csd-enable = false;
      dark-theme-enable = true;
    };
  };
}
