{
  catppuccinPalette,
  config,
  lib,
  pkgs,
  ...
}:
let
  host = config.noughty.host;
in
lib.mkIf host.is.workstation {
  # User specific dconf settings; only intended as override for NixOS dconf profile user database
  dconf.settings =
    with lib.hm.gvariant;
    lib.mkIf host.is.linux {
      "org/gnome/meld" = {
        custom-font = "FiraCode Nerd Font Mono Medium 13";
        indent-width = mkInt32 4;
        insert-spaces-instead-of-tabs = true;
        highlight-current-line = true;
        show-line-numbers = true;
        prefer-dark-theme = true;
        highlight-syntax = true;
        style-scheme = "catppuccin_${catppuccinPalette.flavor}";
      };
    };

  home = {
    file = {
      "${config.xdg.dataHome}/libgedit-gtksourceview-300/styles/catppuccin-mocha.xml".text =
        builtins.readFile ./gedit-catppuccin-mocha.xml;
    };
    # Packages that are used by some of the extensions below
    packages = with pkgs; [
      meld
    ];
  };
}
