{ desktop, pkgs, ... }: {
  services.flatpak.enable = true;
  xdg.portal.enable = true;
  #xdg.portal.xdgOpenUsePortal = true;
}
