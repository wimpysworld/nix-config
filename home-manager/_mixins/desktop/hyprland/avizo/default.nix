_: {
  # avizo is an osd notification daemon for audio and backlight
  # avizo provides volumectl and lightctl for controlling audio and backlight
  services = {
    avizo = {
      enable = true;
      settings = {
        default = {
          # Catppuccin Mocha theme
          background = "rgba(30, 30, 46, 0.8)";
          bar-bg-color = "rgba(88, 91, 112, 0.9)";
          bar-fg-color = "rgba(137, 180, 250, 0.9)";
          border-color = "rgba(137, 180, 250, 1)";
          border-width = 1;
          block-count = 20;
          block-height = 16;
          block-spacing = 4;
          image-opacity = 0.9;
          padding = 32;
          time = 2;
          fade-in = 0.5;
          fade-out = 0.75;
          width = 480;
          height = 240;
          y-offset = 0.75;
        };
      };
    };
  };
  wayland.windowManager.hyprland = {
    settings = {
      # Work when input inhibitor (l) is active.
      bindl = [
        ", XF86AudioMute, exec, volumectl toggle-mute"
        ", XF86AudioMicMute, exec, volumectl -m toggle-mute"
      ];
      # Work when input inhibitor (l) is active, with repeat (e)
      bindle = [
        ", XF86AudioRaiseVolume, exec, volumectl -u up"
        ", XF86AudioLowerVolume, exec, volumectl -u down"
        ", XF86MonBrightnessUp, exec, lightctl up"
        ", XF86MonBrightnessDown, exec, lightctl down"
      ];
    };
  };
}
