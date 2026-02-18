{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./apps
    ./backgrounds
    ./hyprland
    ./wayfire
  ];

  config = lib.mkIf config.noughty.host.is.workstation {
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
        enable = !config.noughty.host.is.iso;
        binfmt = !config.noughty.host.is.iso;
      };
      dconf = {
        enable = true;
      };
    };
    services = {
      flatpak = lib.mkIf (!config.noughty.host.is.iso) {
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
  };
}
