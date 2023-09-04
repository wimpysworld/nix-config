{ pkgs, ... }: {
  services.syncthing = {
    tray = {
      enable = true;
      package = pkgs.unstable.syncthingtray;
    };
  };
}
