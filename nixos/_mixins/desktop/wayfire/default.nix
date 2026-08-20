{
  catppuccinPalette,
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;

  wayfireWithGSettingsSchemas = pkgs.symlinkJoin {
    inherit (pkgs.wayfire) version;
    pname = "wayfire-with-gsettings-schemas";
    paths = [ pkgs.wayfire ];
    nativeBuildInputs = [ pkgs.makeWrapper ];

    postBuild = ''
      wrapProgram $out/bin/wayfire \
        --prefix XDG_DATA_DIRS : ${pkgs.glib.makeSchemaDataDirPath pkgs.gsettings-desktop-schemas pkgs.gsettings-desktop-schemas.name}
    '';

    passthru = pkgs.wayfire.passthru // {
      unwrapped = pkgs.wayfire;
    };

    meta = pkgs.wayfire.meta // {
      outputsToInstall = [ "out" ];
    };
  };
in
{
  config = lib.mkIf (host.desktop == "wayfire") {
    environment = {
      sessionVariables = {
        # Make sure the cursor size is the same in all environments
        XCURSOR_SIZE = 32;
        XCURSOR_THEME = "catppuccin-${catppuccinPalette.flavor}-${catppuccinPalette.accent}-cursors";
        NIXOS_OZONE_WL = 1;
      };
      systemPackages = with pkgs; [
        wayfire
      ];
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
      wayfire = {
        enable = true;
        package = wayfireWithGSettingsSchemas;
        plugins = with pkgs.wayfirePlugins; [
          wcm
          wf-shell
          wayfire-plugins-extra
        ];
      };
    };
  };
}
