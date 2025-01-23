# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
pkgs:
{
  # Local packages being prepped for upstreaming
  davinci-resolve = pkgs.callPackage ./davinci-resolve { };
  defold = pkgs.callPackage ./defold { };
  defold-bob = pkgs.callPackage ./defold-bob { };
  defold-gdc = pkgs.callPackage ./defold-gdc { };
  heynote = pkgs.callPackage ./heynote { };
  open-webui = pkgs.callPackage ./open-webui { };
  station = pkgs.callPackage ./station { };
  nerd-font-patcher = pkgs.callPackage ./nerd-font-patcher { };

  # Local packages to prevent unintended upgrades or carrying patches
  hyprpicker = pkgs.callPackage ./hyprpicker { };
  gotosocial = pkgs.callPackage ./gotosocial { };
  owncast = pkgs.callPackage ./owncast { };

  obs-aitum-multistream = pkgs.qt6Packages.callPackage ./obs-plugins/obs-aitum-multistream.nix { };
  obs-advanced-masks = pkgs.callPackage ./obs-plugins/obs-advanced-masks.nix { };
  obs-browser-transition = pkgs.callPackage ./obs-plugins/obs-browser-transition.nix { };
  obs-dir-watch-media = pkgs.callPackage ./obs-plugins/obs-dir-watch-media.nix { };
  obs-dvd-screensaver = pkgs.callPackage ./obs-plugins/obs-dvd-screensaver.nix { };
  obs-freeze-filter = pkgs.qt6Packages.callPackage ./obs-plugins/obs-freeze-filter.nix { };
  obs-markdown = pkgs.callPackage ./obs-plugins/obs-markdown.nix { };
  obs-media-controls = pkgs.callPackage ./obs-plugins/obs-media-controls.nix { };
  obs-mute-filter = pkgs.callPackage ./obs-plugins/obs-mute-filter.nix { };
  obs-noise = pkgs.callPackage ./obs-plugins/obs-noise.nix { };
  obs-recursion-effect = pkgs.qt6Packages.callPackage ./obs-plugins/obs-recursion-effect.nix { };
  obs-replay-source = pkgs.qt6Packages.callPackage ./obs-plugins/obs-replay-source.nix { };
  obs-retro-effects = pkgs.callPackage ./obs-plugins/obs-retro-effects.nix { };
  obs-rgb-levels = pkgs.callPackage ./obs-plugins/obs-rgb-levels.nix { };
  obs-scale-to-sound = pkgs.callPackage ./obs-plugins/obs-scale-to-sound.nix { };
  obs-scene-as-transition = pkgs.callPackage ./obs-plugins/obs-scene-as-transition.nix { };
  obs-source-clone = pkgs.callPackage ./obs-plugins/obs-source-clone.nix { };
  obs-stroke-glow-shadow = pkgs.callPackage ./obs-plugins/obs-stroke-glow-shadow.nix { };
  obs-transition-table = pkgs.qt6Packages.callPackage ./obs-plugins/obs-transition-table.nix { };
  obs-urlsource = pkgs.qt6Packages.callPackage ./obs-plugins/obs-urlsource.nix { };
  obs-vertical-canvas = pkgs.qt6Packages.callPackage ./obs-plugins/obs-vertical-canvas.nix { };
  obs-vnc = pkgs.callPackage ./obs-plugins/obs-vnc.nix { };
  obs-webkitgtk = pkgs.callPackage ./obs-plugins/obs-webkitgtk.nix { };
  pixel-art = pkgs.callPackage ./obs-plugins/pixel-art.nix { };

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

  # Non-redistributable packages
  cider = pkgs.callPackage ./cider { };
  pico8 = pkgs.callPackage ./pico8 { };
}
