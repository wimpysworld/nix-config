{
  catppuccinPalette,
  config,
  lib,
  ...
}:
let
  inherit (config.noughty) host;
in
{
  config = lib.mkIf (host.desktop == "hyprland") {
    environment.sessionVariables = {
      # Make sure the cursor size is the same in all environments
      HYPRCURSOR_SIZE = 32;
      HYPRCURSOR_THEME = "catppuccin-${catppuccinPalette.flavor}-${catppuccinPalette.accent}-cursors";
      NIXOS_OZONE_WL = 1;
      QT_WAYLAND_DISABLE_WINDOWDECORATION = 1;
    };

    programs = {
      dconf.profiles.user.databases = [
        {
          settings = with lib.gvariant; {
            "org/gnome/desktop/interface" = {
              clock-format = "24h";
              color-scheme = "${catppuccinPalette.preferShade}";
              cursor-size = mkInt32 32;
              cursor-theme = "catppuccin-${catppuccinPalette.flavor}-${catppuccinPalette.accent}-cursors";
              document-font-name = "Work Sans 12";
              font-name = "Work Sans 12";
              gtk-theme = "catppuccin-${catppuccinPalette.flavor}-${catppuccinPalette.accent}-standard";
              gtk-enable-primary-paste = true;
              icon-theme = "Papirus${catppuccinPalette.themeShade}";
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
      hyprland = {
        enable = true;
        systemd.setPath.enable = true;
        withUWSM = false;
      };
      iio-hyprland = {
        enable = true;
      };
      udevil.enable = true;
    };
    services.devmon.enable = true;
  };
}
