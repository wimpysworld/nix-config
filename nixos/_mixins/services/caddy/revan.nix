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

          # - https://jellyfin.org/docs/general/networking/caddy/
          #redir /jellyfin /jellyfin/
          #reverse_proxy /jellyfin/* localhost:8096

          # - https://www.jjpdev.com/posts/plex-media-server-tailscale/
          # - https://furotmark.github.io/2023/01/04/Configuring-Caddy2-With-Plex-And-Transmission.html
          #reverse_proxy /web/* localhost:32400 {
          #  header_up -Referer
          #  header_up -X-Forwarded-For
          #  header_up Origin "${hostname}.drongo-gamma.ts.net" "192.168.2.18"
          #  header_up Host "${hostname}.drongo-gamma.ts.net" "192.168.2.18"
          #  header_down Location "192.168.2.18" "${hostname}.drongo-gamma.ts.net"
          #}

          reverse_proxy localhost:8082
        }
      '';
    };
  };
}
