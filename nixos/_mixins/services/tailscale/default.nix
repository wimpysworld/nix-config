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
  # Trust the tailscale interface, if tailscale is enabled
  networking.firewall = lib.mkIf (config.services.tailscale.enable) {
    trustedInterfaces = [ "tailscale0" ];
  };
  services.tailscale = {
    enable = true;
    extraUpFlags = [ "--accept-routes" "--operator=${username}" "--ssh" ];
    # Enable caddy to acquire certificates from the tailscale daemon
    # - https://tailscale.com/blog/caddy
    permitCertUid = "caddy";
    openFirewall = true;
    useRoutingFeatures = "both";
  };
}
