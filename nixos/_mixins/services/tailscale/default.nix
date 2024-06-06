{ config, ... }: {
  # drongo-gamma.ts.net
  services.tailscale = {
      enable = true;
      extraUpFlags = [ "--accept-routes" "--ssh" ];
      useRoutingFeatures = "client";
  };
  networking = {
    firewall = {
      allowedUDPPorts = [ config.services.tailscale.port ];
      trustedInterfaces = [ "tailscale0" ];
    };
  };
}
