{ inputs, pkgs, ... }: {
  imports = [
    ../services/networkmanager.nix
  ];

  # Exclude MATE themes. Yaru will be used instead.
  # Don't install mate-netbook or caja-dropbox
  environment = {
    mate.excludePackages = with pkgs.mate; [
      mate-themes
      mate-netbook
      caja-dropbox
      mate-icon-theme
      mate-backgrounds
      mate-icon-theme-faenza
    ];

    # Add some packages to complete the MATE desktop
    systemPackages = with pkgs; [
      celluloid
      gnome.gucharmap
      gnome-firmware
      gnome.simple-scan
      inputs.nix-software-center.packages.${system}.nix-software-center
      networkmanagerapplet
      tilix
    ];
  };

  # Enable some programs to provide a complete desktop
  programs = {
    evolution.enable = true;
    gnome-disks.enable = true;
    nm-applet.enable = true;
    system-config-printer.enable = true;
  };

  # Enable services to round out the desktop
  services = {
    blueman.enable = true;
    gnome.gnome-keyring.enable = true;
    system-config-printer.enable = true;
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
  xdg.portal.extraPortals = [ xdg-desktop-portal-gtk ];
}
