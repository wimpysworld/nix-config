{
  config,
  isInstall,
  lib,
  pkgs,
  ...
}:
{
  environment = {
    systemPackages =
      with pkgs;
      lib.optionals isInstall [
        lomiri.morph-browser
        lomiri.lomiri-terminal-app
        lomiri.lomiri-clock-app
        lomiri.lomiri-filemanager-app
        lomiri.lomiri-camera-app
        lomiri.lomiri-calculator-app
        lomiri.teleports
        lomiri.lomiri-gallery-app
        lomiri.lomiri-docviewer-app
      ];
  };

  programs = {
    dconf.profiles.user.databases = [
      {
        settings = with lib.gvariant; {
          "org/gnome/desktop/interface" = {
            clock-format = "24h";
            color-scheme = "prefer-dark";
            cursor-size = mkInt32 32;
            cursor-theme = "catppuccin-mocha-blue-cursors";
            document-font-name = "Work Sans 12";
            font-name = "Work Sans 12";
            gtk-theme = "catppuccin-mocha-blue-standard";
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
  };
  services.xserver.displayManager.lightdm.greeters.lomiri.enable = true;
  services.desktopManager.lomiri.enable = true;
}
