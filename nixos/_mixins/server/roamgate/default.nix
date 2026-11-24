{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  roamgateSopsFile = ../../../../secrets/roamgate.yaml;
  tunnelTokenKey = "CLOUDFLARE_TUNNEL_TOKEN_ROAMGATE_${lib.toUpper host.name}";
  hasTinyauthUsers = lib.hasInfix "\nTINYAUTH_AUTH_USERS:" (
    "\n" + builtins.readFile roamgateSopsFile
  );
  hasTunnelToken = lib.hasInfix "\n${tunnelTokenKey}:" ("\n" + builtins.readFile roamgateSopsFile);
  enableTunnel = hasTunnelToken && hasTinyauthUsers;
in
lib.mkIf (noughtyLib.hostHasTag "roamgate") {
  # Roamgate runs with `NODE_ENV=development` on `127.0.0.1:8787` so Tinyauth is
  # the sole login screen. Restrict loopback TCP port 8787 to the Caddy system
  # user so fenced agents and other local processes cannot bypass Tinyauth.
  networking = {
    nftables.tables.roamgate-local = lib.mkIf config.networking.nftables.enable {
      family = "inet";
      content = ''
        chain output {
          type filter hook output priority 0; policy accept;
          oifname "lo" tcp dport 8787 meta skuid != "${config.services.caddy.user}" reject with tcp reset
        }
      '';
    };
    firewall = lib.mkIf (!config.networking.nftables.enable) {
      extraCommands = ''
        iptables -C OUTPUT -o lo -p tcp --dport 8787 -m owner ! --uid-owner ${config.services.caddy.user} -j REJECT --reject-with tcp-reset 2>/dev/null || \
          iptables -A OUTPUT -o lo -p tcp --dport 8787 -m owner ! --uid-owner ${config.services.caddy.user} -j REJECT --reject-with tcp-reset
        ip6tables -C OUTPUT -o lo -p tcp --dport 8787 -m owner ! --uid-owner ${config.services.caddy.user} -j REJECT --reject-with tcp-reset 2>/dev/null || \
          ip6tables -A OUTPUT -o lo -p tcp --dport 8787 -m owner ! --uid-owner ${config.services.caddy.user} -j REJECT --reject-with tcp-reset
      '';
      extraStopCommands = ''
        while iptables -D OUTPUT -o lo -p tcp --dport 8787 -m owner ! --uid-owner ${config.services.caddy.user} -j REJECT --reject-with tcp-reset 2>/dev/null; do :; done
        while ip6tables -D OUTPUT -o lo -p tcp --dport 8787 -m owner ! --uid-owner ${config.services.caddy.user} -j REJECT --reject-with tcp-reset 2>/dev/null; do :; done
      '';
    };
  };

  sops = {
    secrets = lib.mkMerge [
      (lib.mkIf hasTinyauthUsers {
        "tinyauth/auth-users" = {
          sopsFile = roamgateSopsFile;
          key = "TINYAUTH_AUTH_USERS";
          owner = "root";
          group = "root";
          mode = "0400";
          restartUnits = [ "tinyauth.service" ];
        };
      })
      (lib.mkIf enableTunnel {
        "cloudflare/tunnel-token-roamgate" = {
          sopsFile = roamgateSopsFile;
          key = tunnelTokenKey;
          owner = "root";
          group = "root";
          mode = "0400";
          restartUnits = [ "cloudflared-roamgate.service" ];
        };
      })
    ];

    templates = lib.mkIf hasTinyauthUsers {
      "tinyauth-roamgate.env" = {
        content = ''
          TINYAUTH_AUTH_USERS=${config.sops.placeholder."tinyauth/auth-users"}
        '';
        owner = "root";
        group = "root";
        mode = "0400";
        restartUnits = [ "tinyauth.service" ];
      };
    };
  };

  services = {
    tinyauth = lib.mkIf hasTinyauthUsers {
      enable = true;
      environmentFile = config.sops.templates."tinyauth-roamgate.env".path;
      settings = {
        APPURL = "https://auth-${host.name}.wimpys.world";
        SERVER_ADDRESS = "127.0.0.1";
        SERVER_PORT = 8789;
        AUTH_SECURECOOKIE = true;
        AUTH_SESSIONEXPIRY = 2592000;
        AUTH_SESSIONMAXLIFETIME = 0;
        AUTH_LOGINMAXRETRIES = 3;
        AUTH_LOGINTIMEOUT = 300;
        AUTH_TRUSTEDPROXIES = "127.0.0.1,::1";
        ANALYTICS_ENABLED = false;
        LABELPROVIDER = "none";
      };
    };

    caddy.virtualHosts = lib.mkIf hasTinyauthUsers {
      "http://auth-${host.name}.wimpys.world:8788" = {
        extraConfig = ''
          bind 127.0.0.1
          reverse_proxy 127.0.0.1:8789 {
            header_up X-Forwarded-Proto https
            header_up X-Forwarded-For {http.request.header.CF-Connecting-IP}
          }
        '';
        logFormat = lib.mkDefault ''
          output file /var/log/caddy/roamgate.log
        '';
      };
      "http://herdr-${host.name}.wimpys.world:8788" = {
        extraConfig = ''
          bind 127.0.0.1
          forward_auth 127.0.0.1:8789 {
            uri /api/auth/caddy
            header_up X-Forwarded-Proto https
            header_up X-Forwarded-For {http.request.header.CF-Connecting-IP}
          }
          reverse_proxy 127.0.0.1:8787
        '';
        logFormat = lib.mkDefault ''
          output file /var/log/caddy/roamgate.log
        '';
      };
    };
  };

  systemd.services.cloudflared-roamgate = lib.mkIf enableTunnel {
    description = "Cloudflare Tunnel connector for Roamgate";
    after = [
      "network-online.target"
      "caddy.service"
      "tinyauth.service"
    ];
    wants = [ "network-online.target" ];
    requires = [
      "caddy.service"
      "tinyauth.service"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = lib.concatStringsSep " " [
        (lib.getExe pkgs.cloudflared)
        "tunnel"
        "--no-autoupdate"
        "run"
        "--token-file"
        config.sops.secrets."cloudflare/tunnel-token-roamgate".path
      ];
      Restart = lib.mkDefault "always";
      RestartSec = lib.mkDefault 5;
      User = "root";
      Group = "root";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectControlGroups = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];
    };
  };
}
