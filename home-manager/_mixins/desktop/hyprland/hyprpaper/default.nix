{hostname, ... }:
let
  wallpaperResolution = if hostname == "vader" then "2560x2880" else "1920x1080";
in
{
  # hyprpaper is a wallpaper manager and part of the hyprland suite
  services = {
    hyprpaper = {
      enable = true;
      settings = {
        splash = false;
        splash_offset = 2.0;
        preload = [ "/etc/backgrounds/DeterminateColorway-${wallpaperResolution}.png" ];
        wallpaper = [ ", /etc/backgrounds/DeterminateColorway-${wallpaperResolution}.png" ];
      };
    };
  };
}
