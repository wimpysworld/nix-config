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

  digital-7-font = pkgs.callPackage ./fonts/digital-7-font { };
  impact-label-font = pkgs.callPackage ./fonts/impact-label-font { };
  poppins-font = pkgs.callPackage ./fonts/poppins-font { };
}
