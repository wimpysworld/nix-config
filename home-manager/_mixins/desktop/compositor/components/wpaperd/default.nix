{ config, lib, ... }:
let
  inherit (config.noughty) host;
  inherit (host) displays;
  # Build a resolution string from a display's width and height.
  resolution = d: "${toString d.width}x${toString d.height}";
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
