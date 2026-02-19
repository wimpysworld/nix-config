{ config, lib, ... }:
let
  displays = config.noughty.host.displays;
  # Build a resolution string from a display's width and height.
  resolution = d: "${toString d.width}x${toString d.height}";
  # The first display gets a Catppuccin wallpaper; subsequent displays get Colorway.
  wallpaperVariant = i: if i == 0 then "Catppuccin" else "Colorway";
  wallpaperPath = i: d: "/etc/backgrounds/${wallpaperVariant i}-${resolution d}.png";
in
{
  # hyprpaper is a wallpaper manager and part of the hyprland suite
  services = {
    hyprpaper = {
      enable = true;
      settings = {
        splash = false;
        preload =
          if displays != [ ] then
            lib.unique (lib.imap0 wallpaperPath displays)
          else
            [ "/etc/backgrounds/Catppuccin-1920x1080.png" ];
        wallpaper =
          if displays != [ ] then
            lib.imap0 (i: d: "${d.output}, ${wallpaperPath i d}") displays
          else
            [ ", /etc/backgrounds/Catppuccin-1920x1080.png" ];
      };
    };
  };
}
