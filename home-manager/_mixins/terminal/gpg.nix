{
  config,
  pkgs,
  ...
}:
{
  programs = {
    gpg = {
      enable = true;
    };
  };

  services = {
    gpg-agent = {
      enable = true;
      enableSshSupport = true;
      pinentry.package =
        if config.wayland.windowManager.hyprland.enable then pkgs.pinentry-gnome3 else pkgs.pinentry-curses;
    };
  };
}
