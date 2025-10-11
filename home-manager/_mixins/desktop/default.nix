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

  # Authrorize X11 access in Distrobox
  home = {
    file = lib.mkIf isLinux {
      ".distroboxrc".text = ''${pkgs.xorg.xhost}/bin/xhost +si:localuser:$USER'';
    };
    packages = [
      pkgs.notify-desktop
      pkgs.wlr-randr
      pkgs.wl-clipboard
      pkgs.wtype
    ];
  };

  services = lib.mkIf isLinux {
    gpg-agent.pinentry.package = lib.mkForce pkgs.pinentry-gnome3;
    # https://nixos.wiki/wiki/Bluetooth#Using_Bluetooth_headsets_with_PulseAudio
    mpris-proxy.enable = true;
  };

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
