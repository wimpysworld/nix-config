{
  config,
  hostname,
  isWorkstation,
  isServer,
  lib,
  pkgs,
  username,
  ...
}:
let
  tsExitNodes = [
    "maul"
    "revan"
  ];
in
lib.mkIf (isWorkstation || isServer) {
  environment.systemPackages = with pkgs; lib.optionals isWorkstation [ trayscale ];

  services.tailscale = {
    enable = true;
    extraUpFlags = [
      "--operator=${username}"
    ]
    ++ lib.optional (lib.elem "${hostname}" tsExitNodes) "--advertise-exit-node";
    extraSetFlags = [
      "--operator=${username}"
    ]
    ++ lib.optional (lib.elem "${hostname}" tsExitNodes) "--advertise-exit-node";
    # Enable caddy to acquire certificates from the tailscale daemon
    # - https://tailscale.com/blog/caddy
    permitCertUid = lib.mkIf config.services.caddy.enable "caddy";
    openFirewall = true;
    useRoutingFeatures = "both";
  };
}
