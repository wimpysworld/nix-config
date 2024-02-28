{ hostname, pkgs, ... }:
let
  isInstall = if (builtins.substring 0 4 hostname != "iso-") then true else false;
in
{
  # Exclude MATE themes. Yaru will be used instead.
  # Don't install mate-netbook or caja-dropbox
  environment = {
    mate.excludePackages = with pkgs.mate; [
      caja-dropbox
      eom
      mate-themes
      mate-netbook
      mate-icon-theme
      mate-backgrounds
      mate-icon-theme-faenza
    ];

    # Add some packages to complete the MATE desktop
    systemPackages = with pkgs; [
      gthumb
    ] ++ lib.optionals (isInstall) [
      evolutionWithPlugins
      gnome.gnome-clocks
      gnome.gucharmap
      gnome.simple-scan
      gnome-firmware
      pick-colour-picker
      usbimager
    ];
  };

  # Enable some programs to provide a complete desktop
  programs = {
    evolution.enable = isInstall;
    gnome-disks.enable = isInstall;
    nm-applet = {
      enable = true;
      # When Indicator support for MATE is available in NixOS, this can be true
      indicator = false;
    };
    seahorse.enable = isInstall;
  };

  qt = {
    enable = true;
    platformTheme = "gnome";
    style = "adwaita-dark";
  };

  # Enable services to round out the desktop
  services = {
    blueman.enable = true;
    gnome.evolution-data-server.enable = isInstall;
    gnome.gnome-keyring.enable = true;
    gvfs.enable = true;
    xserver = {
      enable = true;
      displayManager = {
        lightdm.enable = true;
        lightdm.greeters.gtk = {
          enable = true;
          cursorTheme.name = "Yaru";
          cursorTheme.package = pkgs.yaru-theme;
          cursorTheme.size = 32;
          iconTheme.name = "Yaru-magenta-dark";
          iconTheme.package = pkgs.yaru-theme;
          theme.name = "Yaru-magenta-dark";
          theme.package = pkgs.yaru-theme;
          indicators = [
            "~session"
            "~host"
            "~spacer"
            "~clock"
            "~spacer"
            "~a11y"
            "~power"
          ];
          # https://github.com/Xubuntu/lightdm-gtk-greeter/blob/master/data/lightdm-gtk-greeter.conf
          extraConfig = ''
            # background = Background file to use, either an image path or a color (e.g. #772953)
            font-name = Work Sans 12
            xft-antialias = true
            xft-dpi = 96
            xft-hintstyle = slight
            xft-rgba = rgb

            active-monitor = #cursor
            # position = x y ("50% 50%" by default)  Login window position
            # default-user-image = Image used as default user icon, path or #icon-name
            hide-user-image = false
            round-user-image = false
            highlight-logged-user = true
            panel-position = top
            clock-format = %a, %b %d  %H:%M
          '';
        };
      };

      desktopManager = {
        mate.enable = true;
      };
    };
  };
}
