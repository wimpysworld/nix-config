{ config, desktop, hostname, lib, pkgs, username, ... }:
let
  # Declare which hosts have Tailscale enabled.
  installOn = [ "phasma" "tanis" "revan" "sidious" "vader" ];
  tsExitNodes = [ "phasma" "revan" "vader" ];
  isWorkstation = if (desktop != null) then true else false;
in
lib.mkIf (lib.elem "${hostname}" installOn) {
  environment.systemPackages = with pkgs; lib.optionals (isWorkstation) [ trayscale ];

  services.tailscale = {
    enable = true;
    extraUpFlags = [
      "--accept-routes"
      "--operator=${username}"
      "--ssh"
    ] ++ lib.optional (lib.elem "${hostname}" tsExitNodes) "--advertise-exit-node";

    # Enable caddy to acquire certificates from the tailscale daemon
    # - https://tailscale.com/blog/caddy
    permitCertUid = lib.mkIf (config.services.caddy.enable) "caddy";
    openFirewall = true;
    useRoutingFeatures = "both";
  };
}
