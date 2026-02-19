{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  host = config.noughty.host;
  username = config.noughty.user.name;
  tsExitNodes = [
    "maul"
    "revan"
  ];
in
lib.mkIf (host.is.workstation || host.is.server) {
  environment.systemPackages = with pkgs; lib.optionals host.is.workstation [ trayscale ];

  services.tailscale = {
    authKeyFile = lib.mkIf (!host.is.iso) config.sops.secrets.tailscale-auth-key.path;
    authKeyParameters.preauthorized = lib.mkIf (!host.is.iso) true;
    disableUpstreamLogging = true;
    enable = true;
    extraUpFlags = [
      "--operator=${username}"
    ]
    ++ lib.optional (noughtyLib.isHost tsExitNodes) "--advertise-exit-node";
    extraSetFlags = [
      "--operator=${username}"
    ]
    ++ lib.optional (noughtyLib.isHost tsExitNodes) "--advertise-exit-node";
    # Enable caddy to acquire certificates from the tailscale daemon
    # - https://tailscale.com/blog/caddy
    permitCertUid = lib.mkIf config.services.caddy.enable "caddy";
    openFirewall = true;
    useRoutingFeatures = "both";
  };

  sops = lib.mkIf (!host.is.iso) {
    secrets.tailscale-auth-key = {
      sopsFile = ../../../../secrets/tailscale.yaml;
      key = "auth_key";
    };
  };
}
