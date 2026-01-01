{
  catppuccinPalette,
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "martin" ];
  inherit (pkgs.stdenv) isLinux;
in
lib.mkIf (lib.elem username installFor) {
  # User specific dconf settings; only intended as override for NixOS dconf profile user database
  dconf.settings =
    with lib.hm.gvariant;
    lib.mkIf isLinux {
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
      "${config.home.homeDirectory}/.local/share/libgedit-gtksourceview-300/styles/catppuccin-mocha.xml".text =
        builtins.readFile ./gedit-catppuccin-mocha.xml;
    };
    # Packages that are used by some of the extensions below
    packages = with pkgs; [
      meld
    ];
  };
}
