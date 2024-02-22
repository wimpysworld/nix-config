{ config, ... }: {
  services.tailscale.enable = true;
  networking = {
    extraHosts = ''
      100.82.90.87    vader-tail
      100.88.163.93   phasma-tail
    '';
    firewall = {
      checkReversePath = "loose";
      allowedUDPPorts = [ config.services.tailscale.port ];
      trustedInterfaces = [ "tailscale0" ];
    };
  };
}
