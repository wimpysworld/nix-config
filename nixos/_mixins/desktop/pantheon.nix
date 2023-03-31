{ inputs, pkgs, ... }: {
  imports = [
    ../services/networkmanager.nix
  ];

  # Exclude the Epiphany browser
  environment = {
    pantheon.excludePackages = with pkgs.pantheon; [
      epiphany
    ];

    # Add some elementary additional apps and include Yaru for syntax highlighting
    systemPackages = with pkgs; [
      appeditor                   # elementary OS menu editor
      cipher                      # elementary OS text encoding/decoding
      #elementary-planner         # UNSTABLE: elementary OS planner with Todoist support
      formatter                   # elementary OS filesystem formatter
      gnome.simple-scan
      indicator-application-gtk3
      inputs.nix-software-center.packages.${system}.nix-software-center
      minder                      # elementary OS mind-mapping
      monitor                     # elementary OS system monitor
      #nasc                       # UNSTABLE: elementary OS maths notebook
      notes-up                    # elementary OS Markdown editor
      pantheon.sideload           # elementary OS Flatpak installer
      tilix                       # Tiling terminal emulator
      tootle                      # elementary OS Mastodon client
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
        # Use GTK greeter as the Pantheon greeter is not working
        lightdm.greeters.pantheon.enable = false;
        lightdm.greeters.gtk = {
          enable = true;
          cursorTheme.name = "elementary";
          cursorTheme.package = pkgs.pantheon.elementary-icon-theme;
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
