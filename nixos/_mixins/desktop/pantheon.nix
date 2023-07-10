# NOTE: This is the minimum Pantheon, included in the live .iso image
# For actuall installs pantheon-apps.nix is also included
{ pkgs, ... }: {
  imports = [
    ./qt-style.nix
    ../services/networkmanager.nix
  ];

  # Exclude the elementary apps I don't use
  environment = {
    pantheon.excludePackages = with pkgs.pantheon; [
      elementary-music
      elementary-photos
      elementary-videos
      epiphany
    ];

    # App indicator
    # - https://discourse.nixos.org/t/anyone-with-pantheon-de/28422
    # - https://github.com/NixOS/nixpkgs/issues/144045#issuecomment-992487775
    pathsToLink = [ "/libexec" ];
  };

  services = {
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
  systemd.user.services.indicator-application-service = {
    description = "indicator-application-service";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.indicator-application-gtk3}/libexec/indicator-application/indicator-application-service";
    };
  };
}
