{
  hostname,
  ...
}:
{
  # hyprpaper is a wallpaper manager and part of the hyprland suite
  # TODO: Use correct wallpaper path for each host
  services = {
    hyprpaper = {
      enable = true;
      settings = {
        splash = false;
        splash_offset = 2.0;
        preload = [
          "/etc/backgrounds/DeterminateColorway-1920x1080.png"
        ];
        wallpaper = [
          ", /etc/backgrounds/DeterminateColorway-1920x1080.png"
        ];
      };
    };
  };
}
