{ config, ... }: {
  # drongo-gamma.ts.net
  services.tailscale.enable = true;
  networking = {
    firewall = {
      checkReversePath = "loose";
      allowedUDPPorts = [ config.services.tailscale.port ];
      trustedInterfaces = [ "tailscale0" ];
    };
  };
}
