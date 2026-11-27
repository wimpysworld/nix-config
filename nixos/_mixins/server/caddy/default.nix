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
  hasReframe = noughtyLib.hostHasTag "reframe";
  hasShadowEval = noughtyLib.hostHasTag "moltis";
  needsTailscaleRoute = hasReframe || hasShadowEval;
  syncthingConfig = ''
    redir ${basePath} ${basePath}/
    handle_path ${basePath}/* {
      reverse_proxy localhost:8384 {
        header_up Host localhost
      }
    }
  '';
  reframeConfig = ''
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
      reverse_proxy 127.0.0.1:5900
    }

    # noVNC static assets (vnc.html, JS, CSS) served from the Nix store.
    handle_path /novnc/* {
      root * ${pkgs.novnc}/share/webapps/novnc
      file_server
    }
  '';
  shadowEvalConfig = ''
    # Shadow evaluation static dashboard served read-only by user miniserve.
    redir /shadow-eval /shadow-eval/ 301
    handle_path /shadow-eval/* {
      reverse_proxy 127.0.0.1:8085
    }
  '';
  # Only enable caddy if tailscale is enabled, the host is malak, or it runs Roamgate.
  useCaddy =
    config.services.tailscale.enable
    || noughtyLib.isHost [ "malak" ]
    || noughtyLib.hostHasTag "roamgate";
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
      hash = "sha256-fZMorC0HyxM4pLZX1xSsTZtDPNr35MQHdMiHI3OuZHc=";
    };
    virtualHosts."${host.name}.${config.noughty.network.tailNet}" = lib.mkMerge [
      # Reverse proxy syncthing; which is configured/enabled via Home Manager.
      (lib.mkIf config.services.tailscale.enable {
        extraConfig = lib.mkIf (!needsTailscaleRoute) syncthingConfig;
        logFormat = lib.mkDefault ''
          output file /var/log/caddy/tailscale.log
        '';
      })
      # Tailnet-only routes for ReFrame noVNC and shadow evaluation dashboards.
      (lib.mkIf (config.services.tailscale.enable && needsTailscaleRoute) {
        extraConfig = ''
          route {
            @notTailscale {
              not remote_ip 100.64.0.0/10 fd7a:115c:a1e0::/48
            }
            respond @notTailscale 403

            ${lib.optionalString hasReframe reframeConfig}
            ${lib.optionalString hasShadowEval shadowEvalConfig}
            ${syncthingConfig}
          }
        '';
      })
    ];
  };
}
