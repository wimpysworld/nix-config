{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
in
{
  imports = [
    ./apps
    ./backgrounds
    ./hyprland
    ./wayfire
  ];

  config = lib.mkIf (host.is.workstation && !host.is.iso) {
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
        extraConfig = "UseSimpledrm=1";
        logo = pkgs.runCommand "transparent-plymouth-logo.png" { } ''
          ${pkgs.imagemagick}/bin/magick -size 1x1 xc:transparent PNG32:$out
        '';
      };
    };

    catppuccin.plymouth.enable = config.boot.plymouth.enable;

    programs = {
      # https://wiki.nixos.org/w/index.php?title=Appimage
      # https://nixos.org/manual/nixpkgs/stable/#sec-pkgs-appimageTools
      appimage = {
        enable = true;
        binfmt = true;
      };
      dconf = {
        enable = true;
      };
    };
    services = {
      flatpak = {
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
