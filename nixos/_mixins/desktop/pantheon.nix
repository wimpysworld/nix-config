{ inputs, pkgs, ... }: {
  imports = [
    ../services/networkmanager.nix
  ];

  # Exclude the elementary apps I don't use
  environment = {
    pantheon.excludePackages = with pkgs.pantheon; [
      epiphany
      elementary-music
      elementary-videos
    ];

    # Add some elementary additional apps and include Yaru for syntax highlighting
    # Add additional apps and include Yaru for syntax highlighting
    systemPackages = with pkgs; [
      appeditor                   # elementary OS menu editor
      #cipher                     # elementary OS text encoding/decoding
      formatter                   # elementary OS filesystem formatter
      gnome.simple-scan           # Scanning
      indicator-application-gtk3  # App Indicator
      monitor                     # elementary OS system monitor
      #notes-up                   # elementary OS Markdown editor
      pantheon.sideload           # elementary OS Flatpak installer
      tilix                       # Tiling terminal emulator
      torrential                  # elementary OS torrent client
      yaru-theme
    ];
  };

  # Add GNOME Disks and Pantheon Tweaks
  programs = {
    gnome-disks.enable = true;
    pantheon-tweaks.enable = true;
  };

  services = {
    flatpak = {
      enable = true;
    };
    pantheon.apps.enable = true;

    xserver = {
      enable = true;
      displayManager = {
        lightdm.enable = true;
        lightdm.greeters.pantheon.enable = true;
      };

      desktopManager = {
        pantheon = {
          enable = true;
          extraWingpanelIndicators = with pkgs; [
            wingpanel-indicator-ayatana
          ];
        };
      };
    };
  };
}
