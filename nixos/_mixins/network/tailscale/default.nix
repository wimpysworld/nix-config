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
    ]
    ++ lib.optional (noughtyLib.isHost tsExitNodes) "--advertise-exit-node";
    # Enable caddy to acquire certificates from the tailscale daemon
    # - https://tailscale.com/blog/caddy
    permitCertUid = lib.mkIf config.services.caddy.enable "caddy";
    openFirewall = true;
    useRoutingFeatures = if noughtyLib.isHost tsExitNodes then "both" else "client";
  };

  # Run the Tailscale systray as a user service on workstations, bound to
  # the graphical session so it starts and stops with the desktop environment
  systemd.user.services.tailscale-systray = lib.mkIf host.is.workstation {
    description = "Tailscale system tray";
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.tailscale}/bin/tailscale systray";
      Restart = "on-failure";
      RestartSec = 5;
    };
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
