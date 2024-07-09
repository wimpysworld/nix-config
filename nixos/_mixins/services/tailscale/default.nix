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
    extraUpFlags = [ "--accept-routes" "--operator=${username}" "--ssh" ];
    # Enable caddy to acquire certificates from the tailscale daemon
    # - https://tailscale.com/blog/caddy
    permitCertUid = "caddy";
    openFirewall = true;
    useRoutingFeatures = "both";
  };
}
