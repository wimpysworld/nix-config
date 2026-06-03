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
        extraConfig = "UseSimpledrm=0";
        logo = pkgs.runCommand "transparent-plymouth-logo.png" { } ''
          ${pkgs.imagemagick}/bin/magick -size 1x1 xc:transparent PNG32:$out
        '';
        # nixpkgs generates logo-only Catppuccin theme directories before
        # themePackages, which shadows the real Catppuccin Plymouth themes.
        package = pkgs.symlinkJoin {
          name = "plymouth-catppuccin-themes";
          paths = [
            config.catppuccin.sources.plymouth
            (pkgs.plymouth.override {
              systemd = config.boot.initrd.systemd.package;
            })
          ];
        };
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
