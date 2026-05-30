{ config, lib, ... }:
let
  inherit (config.noughty) host;
  inherit (host) displays;
  # Build a resolution string from a display's width and height.
  resolution = d: "${toString d.width}x${toString d.height}";
  # The first display gets a Catppuccin wallpaper; subsequent displays get Colorway.
  wallpaperVariant = i: if i == 0 then "Catppuccin" else "Colorway";
  wallpaperPath = i: d: "/etc/backgrounds/${wallpaperVariant i}-${resolution d}.png";
in
lib.mkIf (host.is.linux && host.is.workstation) {
  # hyprpaper is a wallpaper manager and part of the hyprland suite
  services = {
    hyprpaper = {
      enable = true;
      settings = {
        splash = false;
        # hyprpaper 0.8.x dropped preload= and the flat wallpaper=MONITOR,path
        # syntax. Wallpapers are now anonymous "wallpaper" sections with a
        # monitor and path; an empty monitor is the fallback.
        wallpaper =
          if displays != [ ] then
            lib.imap0 (i: d: {
              monitor = d.output;
              path = wallpaperPath i d;
            }) displays
          else
            [
              {
                monitor = "";
                path = "/etc/backgrounds/Catppuccin-1920x1080.png";
              }
            ];
      };
    };
  };
}
