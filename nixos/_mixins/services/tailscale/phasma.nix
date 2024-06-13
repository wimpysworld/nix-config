{ lib, ... }:
{
  services.tailscale = {
      extraUpFlags = [ "--advertise-exit-node" ];
  };
}
