{ config, ... }: {
  networking = {
    firewall = {
      checkReversePath = "loose";
      allowedUDPPorts = [ config.services.zerotierone.port ];
      trustedInterfaces = [
        "ztwfukvgqh"
        "ztrfyc7hsl"
      ];
    };
  };
  services.zerotierone = {
    enable = true;
    joinNetworks = [
      "e4da7455b2decfb5"
      "3efa5cb78a7329c1"
    ];
  };
}
