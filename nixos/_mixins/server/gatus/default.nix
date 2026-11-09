{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  inherit (config.noughty.network) tailNet;
  tailnetHost = "${host.name}.${tailNet}";
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
        endpoints =
          lib.optionals (noughtyLib.hostHasTag "silo") [
            {
              name = "Silo";
              group = "Media & AI (Revan)";
              url = "http://127.0.0.1:8090/api/v1/health";
              interval = "30s";
              ui.hide-hostname = true;
              conditions = [
                "[STATUS] == 200"
                "[BODY].status == ok"
              ];
            }
            {
              name = "Silo (Jellyfin API)";
              group = "Media & AI (Revan)";
              url = "http://127.0.0.1:8096/System/Info/Public";
              interval = "30s";
              ui.hide-hostname = true;
              conditions = [
                "[STATUS] == 200"
                "[BODY].ServerName == Silo"
              ];
            }
            {
              name = "Silo (Audiobookshelf API)";
              group = "Media & AI (Revan)";
              url = "http://127.0.0.1:13378/ping";
              interval = "30s";
              ui.hide-hostname = true;
              conditions = [
                "[STATUS] == 200"
                "[BODY].success == true"
              ];
            }
          ]
          ++ lib.optional (noughtyLib.hostHasTag "librechat") {
            name = "LibreChat";
            group = "Media & AI (Revan)";
            url = "https://ai.wimpys.world";
            interval = "30s";
            conditions = [
              "[STATUS] == 200"
              "[BODY] == pat(*<title>LibreChat</title>*)"
              "[CERTIFICATE_EXPIRATION] > 48h"
            ];
          }
          ++ lib.optional (noughtyLib.isHost [ "revan" ]) {
            name = "Weave Notes";
            group = "Media & AI (Revan)";
            url = "https://notes.wimpys.world";
            interval = "30s";
            conditions = [
              "[STATUS] == 200"
              "[BODY] == pat(*<title>weave</title>*)"
              "[CERTIFICATE_EXPIRATION] > 48h"
            ];
          }
          ++ lib.optional (noughtyLib.hostHasTag "inference") {
            name = "llama-swap (${host.name})";
            group = "Media & AI (Revan)";
            url = "http://127.0.0.1:8080/health";
            interval = "30s";
            ui.hide-hostname = true;
            conditions = [
              "[STATUS] == 200"
              "[BODY] == OK"
            ];
          }
          ++ [
            {
              name = "Fibre Router";
              group = "Monitoring & Infrastructure";
              url = "icmp://$GATUS_HOME_FIBRE_ROUTER";
              interval = "30s";
              ui.hide-hostname = true;
              conditions = [
                "[RESPONSE_TIME] < 300"
              ];
            }
            {
              name = "Gatus";
              group = "Monitoring & Infrastructure";
              url = "https://gatus.wimpys.world";
              interval = "30s";
              conditions = [
                "[STATUS] == 200"
                "[CERTIFICATE_EXPIRATION] > 48h"
              ];
            }
          ]
          ++ lib.optional (noughtyLib.hostHasTag "homepage") {
            name = "Homepage";
            group = "Monitoring & Infrastructure";
            url = "http://127.0.0.1:8082";
            interval = "30s";
            ui.hide-hostname = true;
            conditions = [
              "[STATUS] == 200"
            ];
          }
          ++ [
            {
              name = "GoAccess Analytics";
              group = "Monitoring & Infrastructure";
              url = "https://goaccess.wimpys.world";
              interval = "30s";
              conditions = [
                "[STATUS] == 401"
                "[CERTIFICATE_EXPIRATION] > 48h"
              ];
            }
          ]
          ++ lib.optional (noughtyLib.hostHasTag "irc-bouncer") {
            name = "Soju IRC Bouncer";
            group = "Monitoring & Infrastructure";
            url = "tcp://127.0.0.1:7667";
            interval = "30s";
            ui.hide-hostname = true;
            conditions = [
              "[CONNECTED] == true"
            ];
          }
          ++ [
            {
              name = "The Cauldron (Matrix)";
              group = "Social & Websites";
              url = "https://matrix.wimpys.world/_matrix/client/versions";
              interval = "30s";
              conditions = [
                "[STATUS] == 200"
                "[CERTIFICATE_EXPIRATION] > 48h"
              ];
            }
            {
              name = "GoToSocial";
              group = "Social & Websites";
              url = "https://wimpysworld.social/api/v1/instance";
              interval = "30s";
              conditions = [
                "[STATUS] == 200"
                "[CERTIFICATE_EXPIRATION] > 48h"
              ];
            }
            {
              name = "Owncast Live";
              group = "Social & Websites";
              url = "https://wimpysworld.live/api/status";
              interval = "30s";
              conditions = [
                "[STATUS] == 200"
                "[CERTIFICATE_EXPIRATION] > 48h"
              ];
            }
            {
              name = "Wimpy's World";
              group = "Social & Websites";
              url = "https://wimpysworld.com";
              interval = "30s";
              conditions = [
                "[STATUS] == 200"
                "[BODY] == pat(*Martin Wimpress</h1>*)"
                "[CERTIFICATE_EXPIRATION] > 48h"
              ];
            }
            {
              name = "Wimpy's Links";
              group = "Social & Websites";
              url = "https://wimpysworld.link";
              interval = "30s";
              conditions = [
                "[STATUS] == 200"
                "[BODY] == pat(*>Wimpy's Links 🔗</h1>*)"
                "[CERTIFICATE_EXPIRATION] > 48h"
              ];
            }
            {
              name = "What Is My IP";
              group = "Social & Websites";
              url = "https://ip.wimpysworld.com";
              interval = "30s";
              conditions = [
                "[STATUS] == 200"
                "[CERTIFICATE_EXPIRATION] > 48h"
              ];
            }
            {
              name = "Linux Matters";
              group = "Social & Websites";
              url = "https://linuxmatters.sh";
              interval = "30s";
              conditions = [
                "[STATUS] == 200"
                "[BODY] == pat(*New episode every fortnight*)"
                "[CERTIFICATE_EXPIRATION] > 48h"
              ];
            }
            {
              name = "revan";
              group = "Tailnet Fleet";
              url = "icmp://revan.${tailNet}";
              interval = "30s";
              ui.hide-hostname = true;
              conditions = [
                "[RESPONSE_TIME] < 300"
              ];
            }
            {
              name = "malak";
              group = "Tailnet Fleet";
              url = "icmp://malak.${tailNet}";
              interval = "30s";
              ui.hide-hostname = true;
              conditions = [
                "[RESPONSE_TIME] < 300"
              ];
            }
            {
              name = "cognus";
              group = "Tailnet Fleet";
              url = "icmp://cognus.${tailNet}";
              interval = "30s";
              ui.hide-hostname = true;
              conditions = [
                "[RESPONSE_TIME] < 300"
              ];
            }
            {
              name = "Syncthing (${host.name})";
              group = "Tailnet Fleet";
              url = "https://${tailnetHost}/syncthing/rest/noauth/health";
              interval = "30s";
              ui.hide-hostname = true;
              conditions = [
                "[STATUS] == 200"
                "[BODY].status == OK"
                "[CERTIFICATE_EXPIRATION] > 48h"
              ];
            }
            {
              name = "wimpys.world";
              group = "Domain & Certificate Checks";
              url = "https://wimpys.world";
              interval = "3h";
              conditions = [
                "[CERTIFICATE_EXPIRATION] > 48h"
                "[DOMAIN_EXPIRATION] > 168h"
              ];
            }
            {
              name = "wimpysworld.com";
              group = "Domain & Certificate Checks";
              url = "https://wimpysworld.com";
              interval = "3h";
              conditions = [
                "[CERTIFICATE_EXPIRATION] > 48h"
                "[DOMAIN_EXPIRATION] > 168h"
              ];
            }
            {
              name = "wimpysworld.link";
              group = "Domain & Certificate Checks";
              url = "https://wimpysworld.link";
              interval = "3h";
              conditions = [
                "[CERTIFICATE_EXPIRATION] > 48h"
                "[DOMAIN_EXPIRATION] > 168h"
              ];
            }
            {
              name = "wimpysworld.social";
              group = "Domain & Certificate Checks";
              url = "https://wimpysworld.social/api/v1/instance";
              interval = "3h";
              conditions = [
                "[CERTIFICATE_EXPIRATION] > 48h"
                "[DOMAIN_EXPIRATION] > 168h"
              ];
            }
            {
              name = "wimpysworld.live";
              group = "Domain & Certificate Checks";
              url = "https://wimpysworld.live/api/status";
              interval = "3h";
              conditions = [
                "[CERTIFICATE_EXPIRATION] > 48h"
                "[DOMAIN_EXPIRATION] > 168h"
              ];
            }
            {
              name = "linuxmatters.sh";
              group = "Domain & Certificate Checks";
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
