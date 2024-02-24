{ config, ... }: {
  networking = {
    extraHosts = ''
      192.168.192.2   vader-zt
      192.168.192.40  skull-zt
      192.168.192.104 steamdeck-zt
      192.168.192.181 tanis-zt
      192.168.192.162 sidious-zt
      192.168.192.217 phasma-zt
    '';
    firewall = {
      checkReversePath = "loose";
      allowedUDPPorts = [ config.services.zerotierone.port ];
      trustedInterfaces = [
        "ztwfukvgqh"
      ];
    };
  };
  services.zerotierone = {
    enable = true;
    joinNetworks = [
      "e4da7455b2decfb5"
    ];
  };
}
