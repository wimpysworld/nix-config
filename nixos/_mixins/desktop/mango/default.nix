{
  catppuccinPalette,
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
in
{
  config = lib.mkIf (host.desktop == "mango") {
    environment.sessionVariables = {
      # Make sure the cursor size is the same in all environments
      XCURSOR_SIZE = 32;
      XCURSOR_THEME = "catppuccin-${catppuccinPalette.flavor}-${catppuccinPalette.accent}-cursors";
      NIXOS_OZONE_WL = 1;
      WLR_NO_HARDWARE_CURSORS = lib.mkIf (noughtyLib.hostHasTag "reframe") 1;
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
      # The stable module only installs the package, registers its session and
      # writes the portal configuration, so it works with the 0.18 package from
      # the unstable channel.
      mangowc = {
        enable = true;
        package = pkgs.mango;
      };
      udevil.enable = true;
      xwayland.enable = lib.mkDefault true;
    };

    services = {
      devmon.enable = true;
      graphical-desktop.enable = true;
      xserver.desktopManager.runXdgAutostartIfNone = lib.mkDefault true;
    };

    xdg.portal.wlr.enable = true;
  };
}
