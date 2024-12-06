{ config, hostname, lib, pkgs, username, ... }:
let
  installOn = [ "malak" ];
in
lib.mkIf (lib.elem hostname installOn) {
  environment = {
    shellAliases = {
      goaccess-linuxmatters = "sudo ${pkgs.goaccess}/bin/goaccess -f /var/log/caddy/linuxmatters.log --log-format=CADDY --geoip-database=/var/lib/GeoIP/GeoLite2-City.mmdb";
    };
  };
  services = {
    caddy = {
      # The website
      virtualHosts."linuxmatters.sh" = {
        extraConfig = ''
          encode zstd gzip
          root * /mnt/data/www/linuxmatters.sh
          file_server
          handle_errors {
            rewrite * /{err.status_code}.html
            file_server
          }
        '';
        logFormat = lib.mkDefault ''
          output file /var/log/caddy/linuxmatters.log
        '';
      };
      # Redirect http
      virtualHosts."http://linuxmatters.sh" = {
        extraConfig = ''
          redir https://{host}{uri} permanent
        '';
      };
      # Strip the www. and redirect to the apex domain
      # https://caddyserver.com/docs/caddyfile/patterns#redirect-www-subdomain
      virtualHosts."www.linuxmatters.sh" = {
        extraConfig = ''
          redir https://{labels.1}.{labels.0}{uri} permanent
        '';
        logFormat = lib.mkDefault ''
          output file /var/log/caddy/linuxmatters.log
        '';
      };
    };
  };

  systemd.services.goaccess-linuxmatters = {
    description = "Generate goaccess linuxmatters report";
    serviceConfig = {
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.goaccess}/bin/goaccess -f /var/log/caddy/linuxmatters.log --log-format=CADDY -o /mnt/data/www/goaccess/linuxmatters.html --persist --geoip-database=/var/lib/GeoIP/GeoLite2-City.mmdb'";
      User = "${config.services.caddy.user}";
    };
  };
  systemd.timers.goaccess-linuxmatters = {
    description = "Run goaccess linuxmatters report every hour";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "1h";
      RandomizedDelaySec = 300;
    };
  };

  systemd.tmpfiles.rules = [
    "d /mnt/data/www/hugo            0755 ${username} users"
    "d /mnt/data/www/littlelink      0755 ${username} users"
    "d /mnt/data/www/linuxmatters.sh 0755 ${username} users"
  ];
}
