{
  config,
  lib,
  noughtyLib,
  ...
}:
let
  inherit (config.noughty) host;
  basePath = "/scrutiny";
  scrutinyPort = 8081;
in
lib.mkIf (noughtyLib.hostHasTag "scrutiny") {
  services = {
    # Reverse proxy scrutiny if Tailscale is enabled.
    # https://github.com/AnalogJ/scrutiny/blob/master/docs/TROUBLESHOOTING_REVERSE_PROXY.md?plain=1#L62
    caddy.virtualHosts."${host.name}.${config.noughty.network.tailNet}".extraConfig =
      lib.mkIf (config.services.scrutiny.enable && config.services.tailscale.enable)
        ''
          redir ${basePath} ${basePath}/
          reverse_proxy ${basePath}/* localhost:${toString scrutinyPort}
        '';
    scrutiny = {
      enable = true;
      collector = {
        enable = true;
        settings.host.id = "${host.name}";
        settings.api.endpoint = "http://localhost:${toString scrutinyPort}${basePath}";
      };
      settings.web.listen = {
        basepath = basePath;
        port = scrutinyPort;
      };
    };
  };
}
