# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
pkgs: {
  # TODO upgrade-hint; Remove when upgrading to 24.11
  catppuccin-gtk = pkgs.callPackage ./catppuccin-gtk { };
  cpu-x = pkgs.callPackage ./cpu-x { };
  davinci-resolve = pkgs.callPackage ./davinci-resolve { };
  gitkraken = pkgs.callPackage ./gitkraken { };
  joplin-desktop = pkgs.callPackage ./joplin-desktop { };
  lima-bin = pkgs.callPackage ./lima-bin { };
  monitorets = pkgs.callPackage ./monitorets { };
  waybar = pkgs.callPackage ./waybar { };
  zoom-us = pkgs.callPackage ./zoom-us { };
  libcef = pkgs.callPackage ./libcef { };

  # Local packages being prepped for upstreaming
  defold = pkgs.callPackage ./defold { };
  defold-bob = pkgs.callPackage ./defold-bob { };
  defold-gdc = pkgs.callPackage ./defold-gdc { };
  heynote = pkgs.callPackage ./heynote { };
  jan = pkgs.callPackage ./jan { };
  nerd-font-patcher = pkgs.callPackage ./nerd-font-patcher { };
  obs-studio = pkgs.qt6Packages.callPackage ./obs-studio { };
  obs-studio-plugins = pkgs.recurseIntoAttrs (pkgs.callPackage ./obs-studio/plugins { });

  # Non-redistributable packages
  cider = pkgs.callPackage ./cider { };
  pico8 = pkgs.callPackage ./pico8 { };

  # Local fonts
  # - https://yildiz.dev/posts/packing-custom-fonts-for-nixos/
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
