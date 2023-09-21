{ ... }: {
  services = {
    plex = {
      enable = true;
      dataDir = "/mnt/sonnet/State/plex";
      openFirewall = true;
    };
    tautulli = {
      enable = true;
      dataDir = "/mnt/sonnet/State/tautulli";
      openFirewall = true;
    };
}
