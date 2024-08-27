{
  config,
  isInstall,
  hostname,
  lib,
  pkgs,
  username,
  ...
}:
{
  imports = [
    ./greetd.nix
  ];
  environment = {
    # Enable HEIC image previews in Nautilus
    pathsToLink = [ "share/thumbnailers" ];
    sessionVariables = {
      NIXOS_OZONE_WL = "1";
      # Make sure the cursor size is the same in all environments
      HYPRCURSOR_SIZE = 48;
      HYPRCURSOR_THEME = "catppuccin-mocha-blue-cursors";
    };
    systemPackages =
      with pkgs;
      lib.optionals isInstall [
        unstable.decibels
        # Enable HEIC image previews in Nautilus
        libheif
        libheif.out
        loupe           # image viewer
        gnome.nautilus  # file manager
        overskride      # bluetooth manager
        papers
        polkit_gnome
        wdisplays       # display configuration
        gnome.zenity
        unstable.catppuccin-cursors
      ];
  };

  programs = {
    dconf.profiles.user.databases = [
      {
        settings = with lib.gvariant; {
          "org/gnome/desktop/interface" = {
            clock-format = "24h";
            color-scheme = "prefer-dark";
            cursor-size = mkInt32 48;
            cursor-theme = "catppuccin-mocha-blue-cursors";
            document-font-name = "Work Sans 12";
            font-name = "Work Sans 12";
            gtk-theme = "catppuccin-mocha-blue-standard+default";
            gtk-enable-primary-paste = true;
            icon-theme = "Papirus-Dark";
            monospace-font-name = "FiraCode Nerd Font Mono Medium 13";
            text-scaling-factor = mkDouble 1.0;
          };

          "org/gnome/desktop/sound" = {
            theme-name = "freedesktop";
          };

          "org/gtk/gtk4/Settings/FileChooser" = {
            clock-format = "24h";
          };

          "org/gtk/Settings/FileChooser" = {
            clock-format = "24h";
          };
        };
      }
    ];
    evince.enable = false;
    file-roller.enable = isInstall;
    gnome-disks.enable = isInstall;
    hyprland = {
      enable = true;
      #portalPackage
      package = pkgs.unstable.hyprland;
      systemd.setPath.enable = true;
    };
    nautilus-open-any-terminal = {
      enable = true;
      terminal = "alacritty";
    };
    nm-applet = lib.mkIf config.networking.networkmanager.enable {
      enable = true;
      indicator = true;
    };
    seahorse.enable = isInstall;
  };
  security = {
    pam.services.hyprlock = {};
    polkit = {
      enable = true;
    };
  };

  services = {
    dbus = {
      implementation = "broker";
      packages = with pkgs; [
        gcr
      ];
    };
    devmon.enable = true;
    gnome = {
      gnome-keyring.enable = isInstall;
      sushi.enable = isInstall;
    };
    gvfs.enable = true;
    udevil.enable = true;
    udisks2.enable = true;
  };
}
