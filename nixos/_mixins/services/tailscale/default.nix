{ config, desktop, hostname, lib, pkgs, username, ... }:
let
  isWorkstation = if (desktop != null) then true else false;
in
{
  imports = lib.optional (builtins.pathExists (./. + "/${hostname}.nix")) ./${hostname}.nix;
  environment = lib.mkIf (isWorkstation) {
    systemPackages = with pkgs; [
      trayscale
    ];
  };
  services.tailscale = {
      enable = true;
      extraUpFlags = [ "--accept-routes" "--operator ${username}" "--ssh" ];
      useRoutingFeatures = "client";
  };
  networking = {
    firewall = {
      allowedUDPPorts = [ config.services.tailscale.port ];
      trustedInterfaces = [ "tailscale0" ];
    };
  };
}
