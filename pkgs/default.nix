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
  station = pkgs.callPackage ./station { };
  nerd-font-patcher = pkgs.callPackage ./nerd-font-patcher { };

  # Now upstreamed to nixpkgs
  heynote = pkgs.callPackage ./heynote { };

  # Local packages to prevent unintended upgrades or carrying patches
  hyprpicker = pkgs.callPackage ./hyprpicker { };
  gotosocial = pkgs.callPackage ./gotosocial { };
  ollama = pkgs.unstable.callPackage ./ollama { };
  open-webui = pkgs.unstable.callPackage ./open-webui { };
  owncast = pkgs.unstable.callPackage ./owncast { };
  podman-desktop = pkgs.callPackage ./podman-desktop { };

  obs-aitum-multistream = pkgs.qt6Packages.callPackage ./obs-plugins/obs-aitum-multistream.nix { };
  obs-browser-transition = pkgs.callPackage ./obs-plugins/obs-browser-transition.nix { };
  obs-dir-watch-media = pkgs.callPackage ./obs-plugins/obs-dir-watch-media.nix { };
  obs-dvd-screensaver = pkgs.callPackage ./obs-plugins/obs-dvd-screensaver.nix { };
  obs-markdown = pkgs.callPackage ./obs-plugins/obs-markdown.nix { };
  obs-media-controls = pkgs.callPackage ./obs-plugins/obs-media-controls.nix { };
  obs-noise = pkgs.callPackage ./obs-plugins/obs-noise.nix { };
  obs-recursion-effect = pkgs.qt6Packages.callPackage ./obs-plugins/obs-recursion-effect.nix { };
  obs-retro-effects = pkgs.callPackage ./obs-plugins/obs-retro-effects.nix { };
  obs-rgb-levels = pkgs.callPackage ./obs-plugins/obs-rgb-levels.nix { };
  obs-scene-as-transition = pkgs.callPackage ./obs-plugins/obs-scene-as-transition.nix { };
  obs-stroke-glow-shadow = pkgs.callPackage ./obs-plugins/obs-stroke-glow-shadow.nix { };
  obs-urlsource = pkgs.qt6Packages.callPackage ./obs-plugins/obs-urlsource.nix { };
  obs-vnc = pkgs.callPackage ./obs-plugins/obs-vnc.nix { };
  pixel-art = pkgs.callPackage ./obs-plugins/pixel-art.nix { };

  # Check my local modification are in the upstream packages
  obs-advanced-masks = pkgs.callPackage ./obs-plugins/obs-advanced-masks.nix { }; # remove after 25.05
  obs-replay-source = pkgs.qt6Packages.callPackage ./obs-plugins/obs-replay-source.nix { }; # upstream fixes
  obs-source-clone = pkgs.callPackage ./obs-plugins/obs-source-clone.nix { }; # remove after 25.05
  obs-vertical-canvas = pkgs.qt6Packages.callPackage ./obs-plugins/obs-vertical-canvas.nix { }; #remove when upstream updates available

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
  pico8 = pkgs.callPackage ./pico8 { };
}
