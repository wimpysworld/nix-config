{ lib, ... }:
with lib.hm.gvariant;
{
  dconf.settings = {
    "ca/desrt/dconf-editor" = {
      show-warning = false;
    };
  };
}
