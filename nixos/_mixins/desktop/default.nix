{
  config,
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
    consoleLogLevel = 0;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "loglevel=3"
      "vt.global_cursor_default=0"
      "mitigations=off"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
    ];
    plymouth = {
      enable = true;
    };
  };

  catppuccin.plymouth.enable = config.boot.plymouth.enable;

  environment.etc = {
    "backgrounds/Cat-1920px.png".source = ../configs/backgrounds/Cat-1920px.png;
    "backgrounds/Cat-2560px.png".source = ../configs/backgrounds/Cat-2560px.png;
    "backgrounds/Cat-3440px.png".source = ../configs/backgrounds/Cat-3440px.png;
    "backgrounds/Cat-3840px.png".source = ../configs/backgrounds/Cat-3840px.png;
    "backgrounds/Catppuccin-1920x1080.png".source = ../configs/backgrounds/Catppuccin-1920x1080.png;
    "backgrounds/Catppuccin-1920x1200.png".source = ../configs/backgrounds/Catppuccin-1920x1200.png;
    "backgrounds/Catppuccin-2560x1440.png".source = ../configs/backgrounds/Catppuccin-2560x1440.png;
    "backgrounds/Catppuccin-2560x1600.png".source = ../configs/backgrounds/Catppuccin-2560x1600.png;
    "backgrounds/Catppuccin-2560x2880.png".source = ../configs/backgrounds/Catppuccin-2560x2880.png;
    "backgrounds/Catppuccin-3440x1440.png".source = ../configs/backgrounds/Catppuccin-3440x1440.png;
    "backgrounds/Catppuccin-3840x2160.png".source = ../configs/backgrounds/Catppuccin-3840x2160.png;
    "backgrounds/Colorway-1920x1080.png".source = ../configs/backgrounds/Colorway-1920x1080.png;
    "backgrounds/Colorway-1920x1200.png".source = ../configs/backgrounds/Colorway-1920x1200.png;
    "backgrounds/Colorway-2560x1440.png".source = ../configs/backgrounds/Colorway-2560x1440.png;
    "backgrounds/Colorway-2560x1600.png".source = ../configs/backgrounds/Colorway-2560x1600.png;
    "backgrounds/Colorway-2560x2880.png".source = ../configs/backgrounds/Colorway-2560x2880.png;
    "backgrounds/Colorway-3440x1440.png".source = ../configs/backgrounds/Colorway-3440x1440.png;
    "backgrounds/Colorway-3840x2160.png".source = ../configs/backgrounds/Colorway-3840x2160.png;
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
