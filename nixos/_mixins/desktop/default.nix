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
    "backgrounds/DeterminateColorway-1920x1080.png".source = ../configs/backgrounds/DeterminateColorway-1920x1080.png;
    "backgrounds/DeterminateColorway-1920x1200.png".source = ../configs/backgrounds/DeterminateColorway-1920x1200.png;
    "backgrounds/DeterminateColorway-2560x1440.png".source = ../configs/backgrounds/DeterminateColorway-2560x1440.png;
    "backgrounds/DeterminateColorway-2560x2880.png".source = ../configs/backgrounds/DeterminateColorway-2560x2880.png;
    "backgrounds/DeterminateColorway-3440x1440.png".source = ../configs/backgrounds/DeterminateColorway-3440x1440.png;
    "backgrounds/DeterminateColorway-3840x2160.png".source = ../configs/backgrounds/DeterminateColorway-3840x2160.png;
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
