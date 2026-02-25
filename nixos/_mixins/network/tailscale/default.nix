{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  username = config.noughty.user.name;
  tsExitNodes = [
    "maul"
    "revan"
  ];
in
lib.mkIf (host.is.workstation || host.is.server) {
  environment.systemPackages = with pkgs; lib.optionals host.is.workstation [ trayscale ];

  services.tailscale = {
    # OAuth client secret is used directly as the auth key value
    authKeyFile = lib.mkIf (!host.is.iso) config.sops.secrets.tailscale-client-secret.path;
    authKeyParameters = {
      ephemeral = false; # Persistent nodes, not removed when offline
      preauthorized = true; # Skip manual device approval
    };
    disableUpstreamLogging = true;
    enable = true;
    extraUpFlags = [
      "--operator=${username}"
      # OAuth clients require at least one tag; all NixOS nodes share a single tag
      "--advertise-tags=tag:nixos"
    ]
    ++ lib.optional (noughtyLib.isHost tsExitNodes) "--advertise-exit-node";
    extraSetFlags = [
      "--operator=${username}"
      # OAuth clients require at least one tag; all NixOS nodes share a single tag
      "--advertise-tags=tag:nixos"
    ]
    ++ lib.optional (noughtyLib.isHost tsExitNodes) "--advertise-exit-node";
    # Enable caddy to acquire certificates from the tailscale daemon
    # - https://tailscale.com/blog/caddy
    permitCertUid = lib.mkIf config.services.caddy.enable "caddy";
    openFirewall = true;
    useRoutingFeatures = "both";
  };

  sops = lib.mkIf (!host.is.iso) {
    secrets = {
      # Legacy pre-auth key, retained for rollback
      tailscale-auth-key = {
        sopsFile = ../../../../secrets/tailscale.yaml;
        key = "auth_key";
      };
      tailscale-client-id = {
        sopsFile = ../../../../secrets/tailscale.yaml;
        key = "client_id";
      };
      tailscale-client-secret = {
        sopsFile = ../../../../secrets/tailscale.yaml;
        key = "client_secret";
      };
    };
  };
}
