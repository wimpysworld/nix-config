{ config, hostname, lib, tailNet, ... }:
let
  basePath = "/syncthing";
in
{
  services = {
    caddy = {
      # Only enables caddy if tailscale is enabled
      inherit (config.services.tailscale) enable;
      # Reverse proxy syncthing; which is configured/enabled via Home Manager
      virtualHosts."${hostname}.${tailNet}".extraConfig = lib.mkIf
        config.services.tailscale.enable
        ''
          redir ${basePath} ${basePath}/
          handle_path ${basePath}/* {
            reverse_proxy localhost:8384 {
              header_up Host localhost
            }
          }
        '';
    };
  };
}
