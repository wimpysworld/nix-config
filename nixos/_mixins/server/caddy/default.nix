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
  basePath = "/syncthing";
  # Only enable caddy if tailscale is enabled or the host is malak
  useCaddy = config.services.tailscale.enable || noughtyLib.isHost [ "malak" ];
in
lib.mkIf useCaddy {
  environment = {
    shellAliases.caddy-log = "journalctl _SYSTEMD_UNIT=caddy.service";
  };
  services.caddy = {
    enable = true;
    email = "${username}@wimpysworld.com";
    globalConfig = ''
      servers {
        trusted_proxies cloudflare {
          interval 12h
          timeout 15s
        }
      }
    '';
    package = pkgs.caddy.withPlugins {
      plugins = [
        "github.com/WeidiDeng/caddy-cloudflare-ip@v0.0.0-20231130002422-f53b62aa13cb"
      ];
      hash = "sha256-D8D9cU+7lWFruF/+C5iq4FLEUuXDbrtWktQuk9ohnC4=";
    };
    virtualHosts."${host.name}.${config.noughty.network.tailNet}" = lib.mkMerge [
      # Reverse proxy syncthing; which is configured/enabled via Home Manager
      (lib.mkIf config.services.tailscale.enable {
        extraConfig = ''
          redir ${basePath} ${basePath}/
          handle_path ${basePath}/* {
            reverse_proxy localhost:8384 {
              header_up Host localhost
            }
          }
        '';
        logFormat = lib.mkDefault ''
          output file /var/log/caddy/tailscale.log
        '';
      })
      # noVNC web client for browser-based VNC access via the Tailnet
      (lib.mkIf (config.services.tailscale.enable && noughtyLib.hostHasTag "wayvnc") {
        extraConfig = ''
          # Redirect bare /novnc and /novnc/ to the noVNC client.
          # path=/websockify is relative to vnc.html's directory, so noVNC
          # will connect to wss://<host>/novnc/websockify.
          # autoconnect=true skips the connect dialog and connects immediately.
          redir /novnc /novnc/vnc.html?path=websockify&autoconnect=true 301
          redir /novnc/ /novnc/vnc.html?path=websockify&autoconnect=true 301

          # noVNC: WebSocket reverse proxy must be matched BEFORE
          # handle_path strips the prefix, otherwise Caddy's directive
          # ordering may route to file_server instead.
          handle /novnc/websockify {
            reverse_proxy localhost:5900
          }

          # noVNC static assets (vnc.html, JS, CSS) served from the Nix store.
          handle_path /novnc/* {
            root * ${pkgs.novnc}/share/webapps/novnc
            file_server
          }
        '';
      })
    ];
  };
}
