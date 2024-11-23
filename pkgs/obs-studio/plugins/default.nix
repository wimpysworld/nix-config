{ callPackage, qt6Packages }:
# When adding new plugins:
# - Respect alphabetical order. On diversion, file a PR.
# - Plugin name should reflect upstream's name. Including or excluding "obs" prefix/suffix.
# - Add plugin to it's own directory (because of future patches).
{
  obs-aitum-multistream = qt6Packages.callPackage ./obs-aitum-multistream.nix { };
  obs-advanced-masks = callPackage ./obs-advanced-masks.nix { };
  obs-browser-transition = callPackage ./obs-browser-transition.nix { };
  obs-dir-watch-media = callPackage ./obs-dir-watch-media.nix { };
  obs-dvd-screensaver = callPackage ./obs-dvd-screensaver.nix { };
  obs-freeze-filter = qt6Packages.callPackage ./obs-freeze-filter.nix { };
  obs-markdown = callPackage ./obs-markdown.nix { };
  obs-media-controls = callPackage ./obs-media-controls.nix { };
  obs-mute-filter = callPackage ./obs-mute-filter.nix { };
  obs-noise = callPackage ./obs-noise.nix { };
  obs-recursion-effect = qt6Packages.callPackage ./obs-recursion-effect.nix { };
  obs-replay-source = qt6Packages.callPackage ./obs-replay-source.nix { };
  obs-retro-effects = callPackage ./obs-retro-effects.nix { };
  obs-rgb-levels = callPackage ./obs-rgb-levels.nix { };
  obs-scale-to-sound = callPackage ./obs-scale-to-sound.nix { };
  obs-scene-as-transition = callPackage ./obs-scene-as-transition.nix { };
  obs-source-clone = callPackage ./obs-source-clone.nix { };
  obs-stroke-glow-shadow = callPackage ./obs-stroke-glow-shadow.nix { };
  obs-transition-table = qt6Packages.callPackage ./obs-transition-table.nix { };
  obs-urlsource = qt6Packages.callPackage ./obs-urlsource.nix { };
  obs-vertical-canvas = qt6Packages.callPackage ./obs-vertical-canvas.nix { };
  obs-vnc = callPackage ./obs-vnc.nix { };
  obs-webkitgtk = callPackage ./obs-webkitgtk.nix { };
  pixel-art = callPackage ./pixel-art.nix { };
}
