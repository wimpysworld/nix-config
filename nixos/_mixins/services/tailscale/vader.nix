{ lib, ... }:
{
  services.tailscale = {
      extraUpFlags = [ "--advertise-exit-node" ];
      useRoutingFeatures = lib.mkForce "both";
  };
}
