{ config, hostname, lib, pkgs, username, ... }:
let
  installOn = [ "malak" "phasma" "vader" ];
in
lib.mkIf (lib.elem hostname installOn) {
  environment = {
    shellAliases = {
      goaccess-self = "sudo ${pkgs.goaccess}/bin/goaccess -f /var/log/caddy/goaccess.log --log-format=CADDY --geoip-database=/var/lib/GeoIP/GeoLite2-City.mmdb";
    };
    systemPackages = with pkgs; [
      goaccess
    ];
  };
  services = {
    caddy = {
      virtualHosts."goaccess.wimpys.world" = {
        extraConfig = ''
          encode zstd gzip
          root * /mnt/data/www/goaccess
          file_server browse
          basic_auth {
            ${username} $2a$14$aTTqvZOozMWiYBJ0IXkHxOiFuk0LeFHpt.7y0FPum4JO1v2u2KsJy
          }
        '';
        logFormat = lib.mkDefault ''
          output file /var/log/caddy/goaccess.log
        '';
        serverAliases = [
          "stats.wimpys.world"
        ];
      };
    };
    geoipupdate = {
      enable = config.services.caddy.enable;
      settings = {
        AccountID = 1087490;
        EditionIDs = [
          "GeoLite2-ASN"
          "GeoLite2-City"
          "GeoLite2-Country"
        ];
        LicenseKey = { _secret = "${config.sops.secrets.maxmind_key.path}"; };
      };
    };
  };

  sops = {
    secrets = {
       maxmind_key = {
        group = "root";
        mode = "0644";
        owner = "root";
        path = "/var/lib/GeoIP/license.key";
        sopsFile = ../../../../secrets/maxmind.yaml;
      };
    };
  };

  # https://edouard.paris/notes/caddy-logs-and-goaccess/
  systemd.services.goaccess-self = {
    description = "Generate goaccess self report";
    serviceConfig = {
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.goaccess}/bin/goaccess -f /var/log/caddy/goaccess.log --log-format=CADDY -o /mnt/data/www/goaccess/goaccess.html --persist --geoip-database=/var/lib/GeoIP/GeoLite2-City.mmdb'";
      User = "${config.services.caddy.user}";
    };
  };

  systemd.timers.goaccess-self = {
    description = "Run goaccess self report every hour";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "1h";
      RandomizedDelaySec = 300;
    };
  };

  systemd.tmpfiles.rules = [
    "d /mnt/data/www/goaccess 0750 ${config.services.caddy.user} ${config.services.caddy.group}"
  ];
}
