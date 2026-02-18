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
    ./backgrounds
  ]
  ++ lib.optional (builtins.pathExists (./. + "/${desktop}")) ./${desktop};

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

  programs = {
    # https://wiki.nixos.org/w/index.php?title=Appimage
    # https://nixos.org/manual/nixpkgs/stable/#sec-pkgs-appimageTools
    appimage = {
      enable = isInstall;
      binfmt = isInstall;
    };
    dconf = {
      enable = true;
    };
  };
  services = {
    flatpak = lib.mkIf isInstall {
      enable = true;
      update.auto = {
        enable = true;
        onCalendar = "weekly";
      };
    };
    gvfs.enable = true;
    udisks2.enable = true;
    usbmuxd.enable = true;
    xserver = {
      # Disable xterm
      desktopManager.xterm.enable = false;
      excludePackages = [ pkgs.xterm ];
    };
  };
}
