{
  config,
  hostname,
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
lib.mkIf (config.noughty.host.is.workstation || config.noughty.host.is.server) {
  environment.systemPackages =
    with pkgs;
    lib.optionals config.noughty.host.is.workstation [ trayscale ];

  services.tailscale = {
    authKeyFile = lib.mkIf (!config.noughty.host.is.iso) config.sops.secrets.tailscale-auth-key.path;
    authKeyParameters.preauthorized = lib.mkIf (!config.noughty.host.is.iso) true;
    disableUpstreamLogging = true;
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

  sops = lib.mkIf (!config.noughty.host.is.iso) {
    secrets.tailscale-auth-key = {
      sopsFile = ../../../../secrets/tailscale.yaml;
      key = "auth_key";
    };
  };
}
