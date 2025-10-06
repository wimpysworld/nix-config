{
  config,
  desktop,
  lib,
  pkgs,
  username,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux isDarwin;
in
{
  # import the DE specific configuration and any user specific desktop configuration
  imports = [
    ./apps
    ./features
  ]
  ++ lib.optional (builtins.pathExists (./. + "/${desktop}")) ./${desktop}
  ++ lib.optional (builtins.pathExists (
    ./. + "/${desktop}/${username}/default.nix"
  )) ./${desktop}/${username};

  # Enable the Catppuccin theme
  catppuccin = {
    fuzzel.enable = config.programs.fuzzel.enable;
    hyprland.enable = config.wayland.windowManager.hyprland.enable;
    waybar.enable = config.programs.waybar.enable;
    obs.enable = config.programs.obs-studio.enable;
  };

  # Authrorize X11 access in Distrobox
  home.file = lib.mkIf isLinux {
    ".distroboxrc".text = ''${pkgs.xorg.xhost}/bin/xhost +si:localuser:$USER'';
  };

  # https://nixos.wiki/wiki/Bluetooth#Using_Bluetooth_headsets_with_PulseAudio
  services.mpris-proxy.enable = isLinux;

  xdg = {
    portal = {
      config = {
        common = {
          default =
            if config.wayland.windowManager.hyprland.enable then
              [
                "hyprland"
                "gtk"
              ]
            else
              [ "gtk" ];
          # For "Open With" dialogs. GTK portal provides the familiar GNOME-style app chooser.
          "org.freedesktop.impl.portal.AppChooser" = [ "gtk" ];
          "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
          # Inhibit is useful for preventing sleep during media playback
          "org.freedesktop.impl.portal.Inhibit" = [ "gtk" ];
          # GTK portal gives you proper print dialogs.
          "org.freedesktop.impl.portal.Print" = [ "gtk" ];
          # Security/credentials
          "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
          # GTK portal provides desktop settings that GTK apps query (fonts, themes, colour schemes).
          "org.freedesktop.impl.portal.Settings" = [ "gtk" ];
        };
      };
      # Add xset to satisfy xdg-screensaver requirements
      configPackages = [
        pkgs.xorg.xset
      ];
      enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal
        pkgs.xdg-desktop-portal-gtk
      ]
      ++ lib.optionals config.wayland.windowManager.hyprland.enable [
        pkgs.xdg-desktop-portal-hyprland
      ];
      xdgOpenUsePortal = true;
    };
  };
}
