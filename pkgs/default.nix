# Custom packages, that can be defined similarly to ones from nixpkgs
# Build them using 'nix build .#example' or (legacy) 'nix-build -A example'

{ pkgs ? (import ../nixpkgs.nix) { } }: {
  catppuccin-gtk = pkgs.callPackage ./catppuccin-gtk { };
  gitkraken = pkgs.callPackage ./gitkraken { };
  obs-studio = pkgs.callPackage ./obs-studio { };
  obs-studio-plugins = pkgs.callPackage ./obs-studio/plugins { };
  quickemu = pkgs.callPackage ./quickemu { };
  quickgui = pkgs.callPackage ./quickgui { };
  wavebox = pkgs.callPackage ./wavebox { };
  zoom-us = pkgs.callPackage ./zoom-us { };
}
