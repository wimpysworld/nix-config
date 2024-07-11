{ desktop, lib, ... }:
{
  programs.dconf.enable = true;
  xdg = {
    portal = {
      config = {
        common = {
          default = [ "gtk" ];
        };
        gnome = lib.mkIf (desktop == "gnome") {
          default = [
            "gnome"
            "gtk"
          ];
          "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
        };
        pantheon = lib.mkIf (desktop == "pantheon") {
          default = [
            "pantheon"
            "gtk"
          ];
          "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
        };
        x-cinnamon = lib.mkIf (desktop == "mate") {
          default = [
            "xapp"
            "gtk"
          ];
          "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
        };
      };
      enable = true;
      xdgOpenUsePortal = true;
    };
    terminal-exec = {
      enable = true;
      settings = {
        default = [ "Alacritty.desktop" ];
      };
    };
  };
}
