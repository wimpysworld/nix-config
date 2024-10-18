{ config, hostname, lib, tailNet, ... }:
let
  basePath = "/scrutiny";
  installOn = [ "malak" "revan" "phasma" "vader" ];
in
lib.mkIf (lib.elem hostname installOn) {
  services = {
    # Reverse proxy scrutiny if Tailscale is enabled.
    # https://github.com/AnalogJ/scrutiny/blob/master/docs/TROUBLESHOOTING_REVERSE_PROXY.md?plain=1#L62
    caddy.virtualHosts."${hostname}.${tailNet}".extraConfig = lib.mkIf
      (config.services.scrutiny.enable && config.services.tailscale.enable)
      ''
        redir ${basePath} ${basePath}/
        reverse_proxy ${basePath}/* localhost:8080
      '';
    scrutiny = {
      enable = true;
      collector = {
        enable = true;
        settings.host.id = "${hostname}";
        settings.api.endpoint = "http://localhost:8080${basePath}";
      };
      settings.web.listen.basepath = basePath;
    };
  };
}
