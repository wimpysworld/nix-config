{
  config,
  lib,
  noughtyLib,
  ...
}:
let
  inherit (config.noughty) host;
  inherit (host) displays;
  # Build a resolution string from a display's width and height, mapped to an
  # available background image size.
  resolution = d: noughtyLib.backgroundResolution "${toString d.width}x${toString d.height}";
  # The first display gets a Catppuccin wallpaper; subsequent displays get Colorway.
  wallpaperVariant = i: if i == 0 then "Catppuccin" else "Colorway";
  wallpaperPath = i: d: "/etc/backgrounds/${wallpaperVariant i}-${resolution d}.png";
  # Map each display to a wpaperd per-output section keyed by its output name.
  outputSections = lib.listToAttrs (
    lib.imap0 (i: d: {
      name = d.output;
      value = {
        path = wallpaperPath i d;
        mode = "center";
      };
    }) displays
  );
in
lib.mkIf (host.is.linux && host.is.workstation) {
  # wpaperd is a generic wlroots wallpaper daemon, portable across Wayland
  # compositors. Each top-level key is a per-output section written to
  # ~/.config/wpaperd/wallpaper.toml; "default" applies to every output and
  # "any" covers outputs without an explicit section.
  services.wpaperd = {
    enable = true;
    settings = {
      # wpaperd's "center" is its aspect-preserving cover mode: the renderer
      # crops the image to the display aspect ratio around the centre and
      # stretches the result over the whole surface (BackgroundMode::Center in
      # wpaperd's renderer), so every output fills regardless of image size or
      # output scale. wpaperd 1.2.2 has no separate "fill" mode.
      default.mode = "center";
    }
    // (
      if displays != [ ] then
        outputSections
      else
        { any.path = "/etc/backgrounds/Catppuccin-1920x1080.png"; }
    );
  };
}
