{ config, hostname, lib, pkgs, ... }:
let
  installOn = [ "malak" ];
in
lib.mkIf (lib.elem hostname installOn) {
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
    };
  };
  services = {
    caddy = {
      virtualHosts."gatus.wimpys.world" = {
        extraConfig = lib.mkIf (config.services.gatus.enable) ''
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
          ntfy = {
            topic = "$GATUS_NTFY_TOPIC";
            url = "$GATUS_NTFY_URL";
            click = "https://status.wimpys.world";
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
            alerts = [{
              type = "ntfy";
            }];
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
            alerts = [{
              type = "ntfy";
            }];
          }
          {
            name = "Website";
            group = "Ubuntu MATE";
            url = "https://ubuntu-mate.org/";
            interval = "30s";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{
              type = "ntfy";
            }];
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
            alerts = [{
              type = "ntfy";
            }];
          }
          {
            name = "Start Page";
            group = "Ubuntu MATE";
            url = "https://start.ubuntu-mate.org/";
            interval = "30s";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{
              type = "ntfy";
            }];
          }
          {
            name = "Discourse";
            group = "Ubuntu MATE Discourse";
            url = "https://ubuntu-mate.community/";
            interval = "30s";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{
              type = "ntfy";
            }];
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
            alerts = [{
              type = "ntfy";
            }];
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
            alerts = [{
              type = "ntfy";
            }];
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
            alerts = [{
              type = "ntfy";
            }];
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
            alerts = [{
              type = "ntfy";
            }];
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
            alerts = [{
              type = "ntfy";
            }];
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
            alerts = [{
              type = "ntfy";
            }];
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
            alerts = [{
              type = "ntfy";
            }];
          }
          {
            name = "Website";
            group = "Linux Matters";
            url = "https://linuxmatters.sh";
            interval = "30s";
            conditions = [
              "[STATUS] == 200"
              "[BODY] == pat(*A new episode every two weeks covering terminal productivity, desktop experience, development, gaming, hosting, hardware, community, cloud-native and all the Linux Matters that matter.*)"
            ];
            alerts = [{
              type = "ntfy";
            }];
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
            alerts = [{
              type = "ntfy";
            }];
          }
          {
            name = "Ping";
            group = "Linux Matters";
            url = "icmp://linuxmatters.sh";
            interval = "30s";
            conditions = [
              "[RESPONSE_TIME] < 300"
            ];
            alerts = [{
              type = "ntfy";
            }];
          }
        ];
      };
    };
  };

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
