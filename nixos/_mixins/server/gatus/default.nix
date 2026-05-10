{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  hermesSopsFile = ../../../../secrets + "/hermes.yaml";
in
lib.mkIf (noughtyLib.hostHasTag "gatus") {
  environment = {
    shellAliases = {
      gatus-log = "journalctl _SYSTEMD_UNIT=gatus.service";
      goaccess-gatus = "sudo ${pkgs.goaccess}/bin/goaccess -f /var/log/caddy/gatus.log --log-format=CADDY --geoip-database=/var/lib/GeoIP/GeoLite2-City.mmdb";
    };
  };
  sops = {
    secrets = {
      gatus-env = {
        group = "root";
        mode = "0644";
        owner = "root";
        path = "/etc/gatus/secrets.env";
        sopsFile = ../../../../secrets/gatus.yaml;
      };
      TELEGRAM_BOT_TOKEN = {
        group = "root";
        mode = "0400";
        owner = "root";
        sopsFile = hermesSopsFile;
      };
    };
    templates."gatus-telegram-env" = {
      content = ''
        GATUS_TELEGRAM_TOKEN=${config.sops.placeholder.TELEGRAM_BOT_TOKEN}
      '';
      group = "root";
      mode = "0400";
      owner = "root";
    };
  };
  services = {
    caddy = lib.mkIf config.services.gatus.enable {
      virtualHosts."gatus.wimpys.world" = {
        extraConfig = ''
          reverse_proxy localhost:${toString config.services.gatus.settings.web.port}
        '';
        logFormat = lib.mkDefault ''
          output file /var/log/caddy/gatus.log
        '';
        serverAliases = [
          "status.wimpys.world"
        ];
      };
    };
    gatus = {
      enable = true;
      environmentFile = config.sops.secrets.gatus-env.path;
      settings = {
        alerting = {
          telegram = {
            token = "$GATUS_TELEGRAM_TOKEN";
            id = "-1003933927882";
            topic-id = "5657";
            default-alert = {
              description = "Gatus health check";
              send-on-resolved = true;
              failure-threshold = 5;
              success-threshold = 2;
            };
          };
        };
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
        web.port = 8181;
        endpoints = [
          {
            name = "Website";
            group = "MATE Desktop";
            url = "https://mate-desktop.org/";
            interval = "30s";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [
              {
                type = "telegram";
              }
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
            alerts = [
              {
                type = "telegram";
              }
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
            alerts = [
              {
                type = "telegram";
              }
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
            alerts = [
              {
                type = "telegram";
              }
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
            alerts = [
              {
                type = "telegram";
              }
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
            alerts = [
              {
                type = "telegram";
              }
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
            alerts = [
              {
                type = "telegram";
              }
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
            alerts = [
              {
                type = "telegram";
              }
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
            alerts = [
              {
                type = "telegram";
              }
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
            alerts = [
              {
                type = "telegram";
              }
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
            alerts = [
              {
                type = "telegram";
              }
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
            alerts = [
              {
                type = "telegram";
              }
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
            alerts = [
              {
                type = "telegram";
              }
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
            alerts = [
              {
                type = "telegram";
              }
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
            alerts = [
              {
                type = "telegram";
              }
            ];
          }
          {
            name = "Ping";
            group = "Linux Matters";
            url = "icmp://linuxmatters.sh";
            interval = "30s";
            conditions = [
              "[RESPONSE_TIME] < 300"
            ];
            alerts = [
              {
                type = "telegram";
              }
            ];
          }
        ];
      };
    };
  };

  systemd.services.gatus.serviceConfig.EnvironmentFile = [
    config.sops.templates."gatus-telegram-env".path
  ];

  systemd.services.goaccess-gatus = {
    description = "Generate goaccess gatus report";
    serviceConfig = {
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.goaccess}/bin/goaccess -f /var/log/caddy/gatus.log --log-format=CADDY -o /mnt/data/www/goaccess/gatus.html --persist --geoip-database=/var/lib/GeoIP/GeoLite2-City.mmdb'";
      User = "${config.services.caddy.user}";
    };
  };

  systemd.timers.goaccess-gatus = {
    description = "Run goaccess gatus report every hour";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "1h";
      RandomizedDelaySec = 300;
    };
  };
}
