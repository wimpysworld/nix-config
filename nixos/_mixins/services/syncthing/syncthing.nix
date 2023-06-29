{ config, hostname, username, ... }: {
  # https://nixos.wiki/wiki/Syncthing
  # https://wes.today/nixos-syncthing/

  # FIXME: This does not appear to work, using Home Manager for now.
  #services.syncthing = {
  #  configDir = "/home/${username}/Syncthing/Devices/${hostname}";
  #  dataDir = "/home/${username}/Syncthing";
  #  enable = true;
  #  user = "${username}";
  #  group = "${username}";
  #  guiAddress = "0.0.0.0:8384";
  #  openDefaultPorts = true;
  #};

  networking = {
    firewall = {
      allowedTCPPorts = [ 8384 22000];
      allowedUDPPorts = [ 22000 21027];
    };
  };
}
