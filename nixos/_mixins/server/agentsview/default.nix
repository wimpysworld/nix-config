{
  config,
  lib,
  noughtyLib,
  ...
}:
{
  imports = [
    ./module.nix
  ];

  config = lib.mkIf (noughtyLib.hostHasTag "agentsview") {
    environment.shellAliases.agentsview-log = "journalctl _SYSTEMD_UNIT=agentsview.service";

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
