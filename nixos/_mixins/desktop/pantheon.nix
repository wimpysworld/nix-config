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

    # App indicator
    # - https://discourse.nixos.org/t/anyone-with-pantheon-de/28422
    # - https://github.com/NixOS/nixpkgs/issues/144045#issuecomment-992487775
    pathsToLink = [ "/libexec" ];

    # Add additional apps and include Yaru for syntax highlighting
    systemPackages = with pkgs; [
      appeditor                   # elementary OS menu editor
      celluloid                   # Video Player
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

  # Add GNOME Disks, Pantheon Tweaks and Seahorse
  programs = {
    gnome-disks.enable = true;
    pantheon-tweaks.enable = true;
    seahorse.enable = true;
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
            monitor
            wingpanel-indicator-ayatana
          ];
        };
      };
    };
  };

  # App indicator
  # - https://github.com/NixOS/nixpkgs/issues/144045#issuecomment-992487775
  systemd.user.services.indicatorapp = {
    description = "indicator-application-gtk3";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.indicator-application-gtk3}/libexec/indicator-application/indicator-application-service";
    };
  };
}
