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
        lightdm.greeters.slick = {
          enable = true;
          draw-user-backgrounds = false;
          cursorTheme.name = "Yaru";
          cursorTheme.size = 32;
          cursorTheme.package = pkgs.pantheon.elementary-icon-theme;
          font.name = "Work Sans 12";
          font.package = pkgs.work-sans;
          iconTheme.package = pkgs.yaru-theme;
          iconTheme.name = "Yaru-magenta-dark";
          theme.package = pkgs.yaru-theme;
          theme.name = "Yaru-magenta-dark";
          extraConfig = ''
# activate-numlock=Whether to activate numlock. This features requires the installation of numlockx. (true or false)
activate-numlock=false
# background=Background file to use, either an image path or a color (e.g. #772953)
# background-color=Background color (e.g. #772953), set before wallpaper is seen
# draw-user-backgrounds=Whether to draw user backgrounds (true or false)
# draw-grid=Whether to draw an overlay grid (true or false)
draw-grid=true
# show-hostname=Whether to show the hostname in the menubar (true or false)
show-hostname=true
# show-power=Whether to show the power indicator in the menubar (true or false)
show-power=true
# show-a11y=Whether to show the accessibility options in the menubar (true or false)
show-all1=true
# show-keyboard=Whether to show the keyboard indicator in the menubar (true or false)
show-keyboard=true
# show-clock=Whether to show the clock in the menubar (true or false)
show-clock=true
# show-quit=Whether to show the quit menu in the menubar (true or false)
show-quit=true
# logo=Logo file to use
# other-monitors-logo=Logo file to use for other monitors
# xft-antialias=Whether to antialias Xft fonts (true or false)
xft-antialias=true
# xft-dpi=Resolution for Xft in dots per inch
xft-dpi=96
# xft-hintstyle=What degree of hinting to use (hintnone/hintslight/hintmedium/hintfull)
xft-hintstyle=hintslight
# xft-rgba=Type of subpixel antialiasing (none/rgb/bgr/vrgb/vbgr)
xft-rgba=rgb
# onscreen-keyboard=Whether to enable the onscreen keyboard (true or false)
onscreen-keyboard=false
# high-contrast=Whether to use a high contrast theme (true or false)
high-contrast=false
# screen-reader=Whether to enable the screen reader (true or false)
screen-reader=true
# play-ready-sound=A sound file to play when the greeter is ready
# hidden-users=List of usernames (separated by semicolons) that are hidden until Ctr+Alt+Shift is pressed
# group-filter=List of groups that users must be part of to be shown (empty list shows all users)
# enable-hidpi=Whether to enable HiDPI support (on/off/auto)
enable-hidpi=auto
# only-on-monitor=Sets the monitor on which to show the login window, -1 means "follow the mouse"
only-on-monitor=-1
# stretch-background-across-monitors=Whether to stretch the background across multiple monitors (false by default)
stretch-background-across-monitors=false
# clock-format=What clock format to use (e.g., %H:%M or %l:%M %p)
clock-format=%H:%M
          '';
        };
      };

      desktopManager = {
        mate.enable = true;
      };
      layout = "gb";
    };
  };
  xdg.portal.extraPortals = [ xdg-desktop-portal-gtk ];
}
