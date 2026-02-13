# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
pkgs: {
  # Local packages
  cider = pkgs.callPackage ./cider { };
  davinci-resolve = pkgs.callPackage ./davinci-resolve { };
  heynote = pkgs.callPackage ./heynote { };
  defold = pkgs.callPackage ./defold { };
  defold-bob = pkgs.callPackage ./defold-bob { };
  defold-gdc = pkgs.callPackage ./defold-gdc { };
  obs-urlsource = pkgs.qt6Packages.callPackage ./obs-plugins/obs-urlsource.nix { };
  obs-vertical-canvas = pkgs.qt6Packages.callPackage ./obs-plugins/obs-vertical-canvas.nix { };
  obs-webkitgtk = pkgs.callPackage ./obs-plugins/obs-webkitgtk.nix { };
  wavebox = pkgs.callPackage ./wavebox { };

  # Local package overrides
  catppuccin-gtk = pkgs.callPackage ./catppuccin-gtk { };
  kmscon = pkgs.callPackage ./kmscon { };
  libtsm = pkgs.callPackage ./libtsm { };
  wolfictl = pkgs.callPackage ./wolfictl { };

  # Local fonts
  # - https://yildiz.dev/posts/packing-custom-fonts-for-nixos/
  bebas-neue-2014-font = pkgs.callPackage ./fonts/bebas-neue-2014-font { };
  bebas-neue-2018-font = pkgs.callPackage ./fonts/bebas-neue-2018-font { };
  bebas-neue-pro-font = pkgs.callPackage ./fonts/bebas-neue-pro-font { };
  bebas-neue-rounded-font = pkgs.callPackage ./fonts/bebas-neue-rounded-font { };
  bebas-neue-semi-rounded-font = pkgs.callPackage ./fonts/bebas-neue-semi-rounded-font { };
  boycott-font = pkgs.callPackage ./fonts/boycott-font { };
  bw-fusiona-font = pkgs.callPackage ./fonts/bw-fusiona-font { };
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

  # Non-redistributable packages
  pico8 = pkgs.callPackage ./pico8 { };
}
