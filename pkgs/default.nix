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
  nerd-font-patcher = pkgs.callPackage ./nerd-font-patcher { };
  obs-studio = pkgs.callPackage ./obs-studio { };
  obs-studio-plugins = pkgs.callPackage ./obs-studio/plugins { };
  wavebox = pkgs.callPackage ./wavebox { };
  zoom-us = pkgs.callPackage ./zoom-us { };

  # https://yildiz.dev/posts/packing-custom-fonts-for-nixos/
  bebas-neue-2014-font = pkgs.callPackage ./fonts/bebas-neue-2014-font { };
  bebas-neue-2018-font = pkgs.callPackage ./fonts/bebas-neue-2018-font { };
  bebas-neue-pro-font = pkgs.callPackage ./fonts/bebas-neue-pro-font { };
  bebas-neue-rounded-font = pkgs.callPackage ./fonts/bebas-neue-rounded-font { };
  bebas-neue-semi-rounded-font = pkgs.callPackage ./fonts/bebas-neue-semi-rounded-font { };
  boycott-font = pkgs.callPackage ./fonts/boycott-font { };
  commodore-64-pixelized-font = pkgs.callPackage ./fonts/commodore-64-pixelized-font { };
  digital-7-font = pkgs.callPackage ./fonts/digital-7-font { };
  dirty-ego-font = pkgs.callPackage ./fonts/dirty-ego-font { };
  fixedsys-core-font = pkgs.callPackage ./fonts/fixedsys-core-font { };
  fixedsys-excelsior-font = pkgs.callPackage ./fonts/fixedsys-excelsior-font { };
  impact-label-font = pkgs.callPackage ./fonts/impact-label-font { };
  mocha-mattari-font = pkgs.callPackage ./fonts/mocha-mattari-font { };
  poppins-font = pkgs.callPackage ./fonts/poppins-font { };
  spaceport-2006-font = pkgs.callPackage ./fonts/spaceport-2006-font { };
  zx-spectrum-7-font = pkgs.callPackage ./fonts/zx-spectrum-7-font { };
}
