# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
pkgs:
{
  # Local packages being prepped for upstreaming
  cider = pkgs.callPackage ./cider { };
  davinci-resolve = pkgs.callPackage ./davinci-resolve { };
  defold = pkgs.callPackage ./defold { };
  defold-bob = pkgs.callPackage ./defold-bob { };
  defold-gdc = pkgs.callPackage ./defold-gdc { };
  wavebox = pkgs.callPackage ./wavebox { };
  nerd-font-patcher = pkgs.callPackage ./nerd-font-patcher { };

  # Local packages to prevent unintended upgrades or carrying patches
  gotosocial = pkgs.callPackage ./gotosocial { };
  joplin-desktop = pkgs.callPackage ./joplin-desktop { };
  nh = pkgs.callPackage ./nh { };
  owncast = pkgs.unstable.callPackage ./owncast { };
  wolfictl = pkgs.callPackage ./wolfictl { };

  # In my OBS Studio Configuration and in review upstream
  obs-aitum-multistream = pkgs.qt6Packages.callPackage ./obs-plugins/obs-aitum-multistream.nix { };   #merged
  obs-dvd-screensaver = pkgs.callPackage ./obs-plugins/obs-dvd-screensaver.nix { };						        #merged
  obs-markdown = pkgs.callPackage ./obs-plugins/obs-markdown.nix { };                                 #merged
  obs-rgb-levels = pkgs.callPackage ./obs-plugins/obs-rgb-levels.nix { }; 								            #merged
  obs-scene-as-transition = pkgs.callPackage ./obs-plugins/obs-scene-as-transition.nix { };				    #merged
  obs-stroke-glow-shadow = pkgs.callPackage ./obs-plugins/obs-stroke-glow-shadow.nix { };				      #merged
  obs-urlsource = pkgs.qt6Packages.callPackage ./obs-plugins/obs-urlsource.nix { };						        #merged
  obs-vertical-canvas = pkgs.qt6Packages.callPackage ./obs-plugins/obs-vertical-canvas.nix { };
  pixel-art = pkgs.callPackage ./obs-plugins/pixel-art.nix { };											                  #merged

  # In review upstream
  obs-browser-transition = pkgs.callPackage ./obs-plugins/obs-browser-transition.nix { };
  obs-vnc = pkgs.callPackage ./obs-plugins/obs-vnc.nix { };

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
