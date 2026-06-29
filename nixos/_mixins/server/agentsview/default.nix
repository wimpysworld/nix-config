{
  config,
  lib,
  noughtyLib,
  ...
}:
let
  inherit (config.noughty) host;
  basePath = "/agentsview";
  # Keep this in sync with the `--port` flag in module.nix; AgentsView listens
  # on localhost only and Caddy reverse-proxies into it.
  agentsviewPort = 18080;
in
{
  imports = [
    ./module.nix
  ];

  config = lib.mkIf (noughtyLib.hostHasTag "agentsview") {
    environment.shellAliases.agentsview-log = "journalctl _SYSTEMD_UNIT=agentsview.service";

    # Reverse proxy AgentsView at /agentsview when Caddy and Tailscale are
    # enabled. AgentsView is launched with `--base-path /agentsview`, so it
    # already serves on the prefixed path; forward the path through verbatim
    # rather than stripping it.
    services.caddy.virtualHosts."${host.name}.${config.noughty.network.tailNet}".extraConfig =
      lib.mkIf (config.services.caddy.enable && config.services.tailscale.enable)
        ''
          redir ${basePath} ${basePath}/
          reverse_proxy ${basePath}/* 127.0.0.1:${toString agentsviewPort}
        '';

    # The sops secret stores AGENTSVIEW_PG_URL as a raw URL value, not a
    # KEY=VALUE pair, so it cannot be passed directly to systemd's
    # EnvironmentFile. A sops template assembles a properly-formatted env
    # file by interpolating the placeholder at activation time. Owning it as
    # `agentsview` lets the service user read it without DynamicUser tricks.
    sops.secrets.AGENTSVIEW_PG_URL = {
      sopsFile = ../../../../secrets/agentsview.yaml;
      owner = "root";
      group = "root";
      mode = "0400";
    };

    sops.templates."agentsview.env" = {
      content = ''
        AGENTSVIEW_PG_URL=${config.sops.placeholder.AGENTSVIEW_PG_URL}
      '';
      owner = "agentsview";
      group = "agentsview";
      mode = "0400";
    };
  };
}
