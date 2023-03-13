{ pkgs, ... }: {
  services = {
    avahi = {
      enable = true;
      nssmdns = true;
    };
  };
}
