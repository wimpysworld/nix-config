{ config, hostname, lib, pkgs, username, ... }:
let
  installOn = [ "malak" ];
in
lib.mkIf (lib.elem hostname installOn) {
  environment = {
    shellAliases = {
      goaccess-gotosocial = "sudo ${pkgs.goaccess}/bin/goaccess -f /var/log/caddy/gotosocial.log --log-format=CADDY --geoip-database=/var/lib/GeoIP/GeoLite2-City.mmdb";
      gotosocial-log = "journalctl _SYSTEMD_UNIT=gotosocial.service";
    };
  };
  sops = {
    secrets = {
      gotosocial-env = {
        group = "gotosocial";
        mode = "0644";
        owner = "gotosocial";
        path = "/mnt/data/gotosocial/secrets.env";
        sopsFile = ../../../../secrets/gotosocial.yaml;
      };
    };
  };
  services = {
    caddy = lib.mkIf config.services.gotosocial.enable {
      # Reverse proxy to the GoToSocial instance
      virtualHosts."${config.services.gotosocial.settings.host}" = {
        extraConfig = ''
          encode zstd gzip
          reverse_proxy ${config.services.gotosocial.settings.bind-address}:${toString config.services.gotosocial.settings.port}
          {
            # Flush immediately, to prevent buffered response to the client
            flush_interval -1
          }
        '';
        logFormat = lib.mkDefault ''
          output file /var/log/caddy/gotosocial.log
        '';
      };
      # Strip the www. and redirect to the apex domain
      virtualHosts."www.${config.services.gotosocial.settings.host}" = {
        extraConfig = ''
          redir https://${config.services.gotosocial.settings.host}{uri} permanent
        '';
        logFormat = lib.mkDefault ''
          output file /var/log/caddy/gotosocial.log
        '';
      };
    };
    gotosocial = {
      enable = true;
      environmentFile = config.sops.secrets.gotosocial-env.path;
      settings = {
        bind-address = "127.0.0.1";
        db-type = "sqlite";
        host = "wimpysworld.social";
        instance-expose-public-timeline = true;
        instance-inject-mastodon-version = true;
        instance-languages = [ "en" ];
        landing-page-user = "${username}";
        letsencrypt-enabled = false;
        media-ffmpeg-pool-size = 4;
        port = 8282;
        statuses-max-chars = 1000;
        statuses-media-max-files = 5;
        statuses-poll-max-options = 5;
        storage-local-base-path = "/mnt/data/gotosocial/storage";
      };
    };
  };

  systemd.services.goaccess-gotosocial = {
    description = "Generate goaccess gotosocial report";
    serviceConfig = {
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.goaccess}/bin/goaccess -f /var/log/caddy/gotosocial.log --log-format=CADDY -o /mnt/data/www/goaccess/gotosocial.html --persist --geoip-database=/var/lib/GeoIP/GeoLite2-City.mmdb'";
      User = "${config.services.caddy.user}";
    };
  };

  systemd.timers.goaccess-gotosocial = {
    description = "Run goaccess gotosocial report every hour";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "1h";
      RandomizedDelaySec = 300;
    };
  };

  systemd.tmpfiles.rules = [
    "d /mnt/data/gotosocial           0755 gotosocial gotosocial"
    "d /mnt/data/gotosocial/storage   0755 gotosocial gotosocial"
  ];
}
