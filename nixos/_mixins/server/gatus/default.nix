{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  cloudflareSopsFile = ../../../../secrets + "/cloudflare.yaml";
  hasCloudflareSopsFile = builtins.pathExists cloudflareSopsFile;
  gatusPort = 8741;
in
lib.mkIf (noughtyLib.hostHasTag "gatus") {
  environment = {
    shellAliases = {
      gatus-log = "journalctl _SYSTEMD_UNIT=gatus.service";
    };
  };
  sops = {
    secrets = {
      CLOUDFLARE_TUNNEL_TOKEN_GATUS = lib.mkIf hasCloudflareSopsFile {
        group = "root";
        mode = "0400";
        owner = "root";
        path = "/run/secrets/CLOUDFLARE_TUNNEL_TOKEN_GATUS";
        sopsFile = cloudflareSopsFile;
      };
      gatus-env = {
        group = "root";
        mode = "0644";
        owner = "root";
        path = "/etc/gatus/secrets.env";
        sopsFile = ../../../../secrets/gatus.yaml;
      };
    };
  };
  services = {
    gatus = {
      enable = true;
      environmentFile = config.sops.secrets.gatus-env.path;
      openFirewall = lib.mkDefault false;
      settings = {
        connectivity = {
          checker = {
            target = "1.1.1.1:53";
            interval = "60s";
          };
        };
        storage = {
          type = "sqlite";
          path = "/var/lib/gatus/gatus.db";
        };
        ui = {
          title = "Wimpy's World Status";
          header = "Wimpy's World Status";
          description = "Powered by Gatus";
          link = "https://wimpysworld.com/";
          logo = "https://wimpysworld.com/profile.webp";
        };
        web = {
          address = "127.0.0.1";
          port = gatusPort;
        };
        endpoints = [
          {
            name = "Website";
            group = "MATE Desktop";
            url = "https://mate-desktop.org/";
            interval = "30s";
            conditions = [
              "[STATUS] == 200"
            ];
          }
          {
            name = "Domain and Certifcate Check";
            group = "MATE Desktop";
            url = "https://mate-desktop.org/";
            interval = "3h";
            conditions = [
              "[CERTIFICATE_EXPIRATION] > 48h"
              "[DOMAIN_EXPIRATION] > 168h"
            ];
          }
          {
            name = "Website";
            group = "Ubuntu MATE";
            url = "https://ubuntu-mate.org/";
            interval = "30s";
            conditions = [
              "[STATUS] == 200"
            ];
          }
          {
            name = "Domain and Certifcate Check";
            group = "Ubuntu MATE";
            url = "https://ubuntu-mate.org/";
            interval = "3h";
            conditions = [
              "[CERTIFICATE_EXPIRATION] > 48h"
              "[DOMAIN_EXPIRATION] > 168h"
            ];
          }
          {
            name = "Start Page";
            group = "Ubuntu MATE";
            url = "https://start.ubuntu-mate.org/";
            interval = "30s";
            conditions = [
              "[STATUS] == 200"
            ];
          }
          {
            name = "Discourse";
            group = "Ubuntu MATE Discourse";
            url = "https://ubuntu-mate.community/";
            interval = "30s";
            conditions = [
              "[STATUS] == 200"
            ];
          }
          {
            name = "Domain and Certifcate Check";
            group = "Ubuntu MATE Discourse";
            url = "https://ubuntu-mate.community/";
            interval = "3h";
            conditions = [
              "[CERTIFICATE_EXPIRATION] > 48h"
              "[DOMAIN_EXPIRATION] > 168h"
            ];
          }
          {
            name = "Node - Machester";
            group = "Ubuntu MATE";
            url = "icmp://$GATUS_MAN_UM_HOST";
            interval = "30s";
            ui.hide-hostname = true;
            conditions = [
              "[RESPONSE_TIME] < 300"
            ];
          }
          {
            name = "Node - York";
            group = "Ubuntu MATE";
            url = "icmp://$GATUS_MAN_UM_HOST";
            interval = "30s";
            ui.hide-hostname = true;
            conditions = [
              "[RESPONSE_TIME] < 300"
            ];
          }
          {
            name = "Fibre Router";
            group = "Wimpy's World";
            url = "icmp://$GATUS_HOME_FIBRE_ROUTER";
            interval = "30s";
            ui.hide-hostname = true;
            conditions = [
              "[RESPONSE_TIME] < 300"
            ];
          }
          {
            name = "Website";
            group = "Wimpy's World";
            url = "https://wimpysworld.com";
            interval = "30s";
            conditions = [
              "[STATUS] == 200"
              "[BODY] == pat(*Martin Wimpress</h1>*)"
            ];
          }
          {
            name = "Links";
            group = "Wimpy's World";
            url = "https://wimpysworld.link";
            interval = "30s";
            conditions = [
              "[STATUS] == 200"
              "[BODY] == pat(*>Wimpy's Links 🔗</h1>*)"
            ];
          }
          {
            name = "GotoSocial";
            group = "Wimpy's World";
            url = "https://wimpysworld.social/@martin";
            interval = "30s";
            conditions = [
              "[STATUS] == 200"
              "[BODY] == pat(*>Profile for martin</h2>*)"
            ];
          }
          {
            name = "Website";
            group = "Linux Matters";
            url = "https://linuxmatters.sh";
            interval = "30s";
            conditions = [
              "[STATUS] == 200"
              "[BODY] == pat(*New episode every fortnight*)"
            ];
          }
          {
            name = "Domain and Certifcate Check";
            group = "Linux Matters";
            url = "https://linuxmatters.sh";
            interval = "3h";
            conditions = [
              "[CERTIFICATE_EXPIRATION] > 48h"
              "[DOMAIN_EXPIRATION] > 168h"
            ];
          }
        ];
      };
    };
  };

  systemd.services.cloudflared-gatus = lib.mkIf hasCloudflareSopsFile {
    description = "Cloudflare Tunnel connector for Gatus";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = lib.concatStringsSep " " [
        (lib.getExe pkgs.cloudflared)
        "tunnel"
        "--no-autoupdate"
        "run"
        "--token-file"
        config.sops.secrets.CLOUDFLARE_TUNNEL_TOKEN_GATUS.path
      ];
      Restart = lib.mkDefault "always";
      RestartSec = lib.mkDefault 5;
      User = lib.mkDefault "root";
      Group = lib.mkDefault "root";

      # Restrict the connector to outbound access and secret reads.
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

  # Remotely-managed tunnels store published application routing in
  # Cloudflare. Configure gatus.wimpys.world -> http://127.0.0.1:8741 in
  # the Cloudflare dashboard or API for this tunnel.
}
