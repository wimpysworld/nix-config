{ config, ... }: {
  networking = {
    firewall = {
      checkReversePath = "loose";
      allowedUDPPorts = [ config.services.zerotierone.port ];
      trustedInterfaces = [ "ztwfukvgqh" ];
    };
  };
  services.zerotierone = {
    enable = true;
    joinNetworks = [ "e4da7455b2decfb5" ];
  };
}
