{ config, hostname, lib, pkgs, ... }:
let
  installOn = [ "malak" "revan" ];
  mountPath = if hostname == "malak" then "data" else "snapshot";
in
lib.mkIf (lib.elem hostname installOn) {
  environment = {
    shellAliases = lib.mkIf (hostname == "malak") {
      goaccess-ubuntu-mate-releases = "sudo ${pkgs.goaccess}/bin/goaccess -f /var/log/caddy/ubuntu-mate-releases.log --log-format=CADDY --geoip-database=/var/lib/GeoIP/GeoLite2-City.mmdb";
    };
    systemPackages = with pkgs; [
      garage
    ];
  };

  services = {
    caddy = lib.mkIf (hostname == "malak") {
      virtualHosts."releases.ubuntu-mate.org" = {
        extraConfig = ''
          root * /mnt/${mountPath}/ubuntu-mate/releases
          file_server browse
        '';
        logFormat = lib.mkDefault ''
          output file /var/log/caddy/ubuntu-mate-releases.log
        '';
        serverAliases = [
          "new-releases.ubuntu-mate.org"
        ];
      };
    };
  };

  systemd.services.goaccess-ubuntu-mate-releases = lib.mkIf (hostname == "malak") {
    description = "Generate goaccess ubuntu-mate-releases report";
    serviceConfig = {
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.goaccess}/bin/goaccess -f /var/log/caddy/ubuntu-mate-releases.log --log-format=CADDY -o /mnt/data/www/goaccess/ubuntu-mate-releases.html --persist --geoip-database=/var/lib/GeoIP/GeoLite2-City.mmdb'";
      User = "${config.services.caddy.user}";
    };
  };

  systemd.timers.goaccess-ubuntu-mate-releases = lib.mkIf (hostname == "malak") {
    description = "Run goaccess ubuntu-mate-releases report every hour";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "1h";
      RandomizedDelaySec = 300;
    };
  };

  systemd.tmpfiles.rules = [
    "d /mnt/${mountPath}/ubuntu-mate/releases 0775 nobody users"
  ];
}
