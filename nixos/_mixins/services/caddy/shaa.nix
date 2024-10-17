{ config, hostname, ... }:
{
  services = {
    caddy = {
      inherit (config.services.tailscale) enable;
      extraConfig = ''
        ${hostname}.drongo-gamma.ts.net {
          redir /syncthing /syncthing/
          handle_path /syncthing/* {
            reverse_proxy localhost:8384 {
              header_up Host localhost
            }
          }
          reverse_proxy localhost:8082
        }
      '';
    };
  };
}
