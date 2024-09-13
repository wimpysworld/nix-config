{hostname, ... }:
{
  # hyprpaper is a wallpaper manager and part of the hyprland suite
  services = {
    hyprpaper = {
      enable = true;
      settings = {
        splash = false;
        preload = if hostname == "phasma" then
        [
          "/etc/backgrounds/Catppuccin-3440x1440.png"
          "/etc/backgrounds/Colorway-2560x1600.png"
          "/etc/backgrounds/Colorway-1920x1080.png"
        ]
        else if hostname == "vader" then
        [
          "/etc/backgrounds/Catppuccin-2560x2880.png"
          "/etc/backgrounds/Colorway-2560x2880.png"
          "/etc/backgrounds/Colorway-1920x1080.png"
        ]
        else if hostname == "tanis" then
        [
          "/etc/backgrounds/Catppuccin-1920x1200.png"
        ]
        else
        [
          "/etc/backgrounds/Catppuccin-1920x1080.png"
        ];
        wallpaper = if hostname == "phasma" then
        [
          "DP-1, /etc/backgrounds/Catppuccin-3440x1440.png"
          "HDMI-A-1, /etc/backgrounds/Colorway-2560x1600.png"
          "DP-2, /etc/backgrounds/Colorway-1920x1080.png"
        ]
        else if hostname == "vader" then
        [
          "DP-1, /etc/backgrounds/Catppuccin-2560x2880.png"
          "DP-2, /etc/backgrounds/Colorway-2560x2880.png"
          "DP-3, /etc/backgrounds/Colorway-1920x1080.png"
        ]
        else if hostname == "tanis" then
        [
          "eDP-1, /etc/backgrounds/Catppuccin-1920x1200.png"
        ]
        else
        [
          ", /etc/backgrounds/Catppuccin-1920x1080.png"
        ];
      };
    };
  };
}
