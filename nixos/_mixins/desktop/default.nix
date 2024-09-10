{
  desktop,
  isInstall,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./apps
    ./features
  ] ++ lib.optional (builtins.pathExists (./. + "/${desktop}")) ./${desktop};

  boot = {
    kernelParams = [
      "quiet"
      "vt.global_cursor_default=0"
      "mitigations=off"
    ];
    plymouth = {
      catppuccin.enable = true;
      enable = true;
    };
  };

  environment.etc = {
    "backgrounds/Catppuccin-1920x1080.png".source = ../configs/backgrounds/Catppuccin-1920x1080.png;
    "backgrounds/Catppuccin-1920x1200.png".source = ../configs/backgrounds/Catppuccin-1920x1200.png;
    "backgrounds/Catppuccin-2560x1440.png".source = ../configs/backgrounds/Catppuccin-2560x1440.png;
    "backgrounds/Catppuccin-2560x1600.png".source = ../configs/backgrounds/Catppuccin-2560x1600.png;
    "backgrounds/Catppuccin-2560x2880.png".source = ../configs/backgrounds/Catppuccin-2560x2880.png;
    "backgrounds/Catppuccin-3440x1440.png".source = ../configs/backgrounds/Catppuccin-3440x1440.png;
    "backgrounds/Catppuccin-3840x2160.png".source = ../configs/backgrounds/Catppuccin-3840x2160.png;
  };

  environment.systemPackages =
    with pkgs;
    [
      catppuccin-cursors.mochaBlue
      (catppuccin-gtk.override {
        accents = [ "blue" ];
        size = "standard";
        variant = "mocha";
      })
      (catppuccin-papirus-folders.override {
        flavor = "mocha";
        accent = "blue";
      })
    ]
    ++ lib.optionals isInstall [
      notify-desktop
      wmctrl
      xdotool
      ydotool
    ];
  programs.dconf.enable = true;
  services = {
    dbus.enable = true;
    usbmuxd.enable = true;
    xserver = {
      # Disable xterm
      desktopManager.xterm.enable = false;
      excludePackages = [ pkgs.xterm ];
    };
  };
}
