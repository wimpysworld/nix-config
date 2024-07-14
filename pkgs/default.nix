# Custom packages, that can be defined similarly to ones from nixpkgs
# Build them using 'nix build .#example' or (legacy) 'nix-build -A example'
{
  pkgs ? (import ../nixpkgs.nix) { },
}:
{
  catppuccin-gtk = pkgs.callPackage ./catppuccin-gtk { };
  gitkraken = pkgs.callPackage ./gitkraken { };
  joplin-desktop = pkgs.callPackage ./joplin-desktop { };
  lima-bin = pkgs.callPackage ./lima-bin { };
  obs-studio = pkgs.callPackage ./obs-studio { };
  obs-studio-plugins = pkgs.callPackage ./obs-studio/plugins { };
  wavebox = pkgs.callPackage ./wavebox { };
  zoom-us = pkgs.callPackage ./zoom-us { };

  commodore-64-pixelized-font = pkgs.callPackage ./fonts/commodore-64-pixelized-font { };
  digital-7-font = pkgs.callPackage ./fonts/digital-7-font { };
  dirty-ego-font = pkgs.callPackage ./fonts/dirty-ego-font { };
  impact-label-font = pkgs.callPackage ./fonts/impact-label-font { };
  poppins-font = pkgs.callPackage ./fonts/poppins-font { };
  spaceport-2006-font = pkgs.callPackage ./fonts/spaceport-2006-font { };
  zx-spectrum-7-font = pkgs.callPackage ./fonts/zx-spectrum-7-font { };
}
