{ lib, ... }:
with lib.hm.gvariant;
{
  dconf.settings = {
    "org/gnome/meld" = {
      indent-width = 4;
      insert-spaces-instead-of-tabs = true;
      highlight-current-line = true;
      show-line-numbers = true;
      prefer-dark-theme = true;
      highlight-syntax = true;
      style-scheme = "Yaru-dark";
    };
  };
}
