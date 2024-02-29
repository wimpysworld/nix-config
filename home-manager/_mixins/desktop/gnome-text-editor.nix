{ config, lib, pkgs, ... }:
let
  inherit (pkgs.stdenv) isLinux;
in
lib.mkIf isLinux {
  home.packages = with pkgs; [
    gnome-text-editor
  ];

  dconf.settings = with lib.hm.gvariant; {
    "org/gnome/TextEditor" = {
      custom-font = "FiraCode Nerd Font Mono Medium 14";
      highlight-current-line = true;
      indent-style = "space";
      show-line-numbers = true;
      show-map = true;
      show-right-margin = true;
      style-scheme = "builder-dark";
      tab-width = mkInt32 4;
      use-system-font = false;
    };
  };
}


