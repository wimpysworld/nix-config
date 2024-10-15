{ config, hostname, ... }:
{
  services = {
    caddy = {
      inherit (config.services.tailscale) enable;
      extraConfig = ''
        ${hostname}.drongo-gamma.ts.net {
          redir /netdata /netdata/
          handle_path /netdata/* {
            reverse_proxy localhost:19999
          }
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
