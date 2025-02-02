{ config, hostname, lib, pkgs, ... }:
let
  installOn = prodOn ++ testOn;
  prodOn = [ "malak" ];
  testOn = [ "revan" ];
  listen = if lib.elem hostname prodOn then "127.0.0.1" else "0.0.0.0";
in
lib.mkIf (lib.elem hostname installOn) {
  environment = {
    shellAliases = {
      goaccess-owncast = "sudo ${pkgs.goaccess}/bin/goaccess -f /var/log/caddy/owncast.log --log-format=CADDY --geoip-database=/var/lib/GeoIP/GeoLite2-City.mmdb";
      owncast-log = "journalctl _SYSTEMD_UNIT=owncast.service";
    };
    systemPackages = with pkgs; [
      owncast
    ];
  };
  services = {
    caddy = lib.mkIf (config.services.owncast.enable && lib.elem hostname prodOn) {
      # Reverse proxy to the GoToSocial instance
      virtualHosts."wimpysworld.live" = {
        extraConfig = ''
          encode zstd gzip
          reverse_proxy ${config.services.owncast.listen}:${toString config.services.owncast.port}
        '';
        logFormat = lib.mkDefault ''
          output file /var/log/caddy/owncast.log
        '';
        serverAliases = [
          "origin.wimpysworld.live"
        ];
      };
      # Strip the www. and redirect to the apex domain
      virtualHosts."www.wimpysworld.live" = {
        extraConfig = ''
          redir https://{labels.1}.{labels.0}{uri} permanent
        '';
        logFormat = lib.mkDefault ''
          output file /var/log/caddy/owncast.log
        '';
      };
    };
    owncast = {
      enable = true;
      inherit listen;
      openFirewall = true;
      port = 8383;
    };
  };

  systemd.services.goaccess-owncast = {
    description = "Generate goaccess owncast report";
    serviceConfig = {
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.goaccess}/bin/goaccess -f /var/log/caddy/owncast.log --log-format=CADDY -o /mnt/data/www/goaccess/owncast.html --persist --geoip-database=/var/lib/GeoIP/GeoLite2-City.mmdb'";
      User = "${config.services.caddy.user}";
    };
  };

  systemd.timers.goaccess-owncast = {
    description = "Run goaccess owncast report every hour";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "1h";
      RandomizedDelaySec = 300;
    };
  };

  systemd.tmpfiles.rules = [
    # Create the directory for the shader cache required by VA-API on AMD
    "d /var/empty/.cache 0777 nobody users"
  ] ++ lib.optionals config.services.geoipupdate.enable [
    # https://owncast.online/docs/viewers/
    "L+ ${config.services.owncast.dataDir}/data/GeoLite2-City.mmdb - - - - ${config.services.geoipupdate.settings.DatabaseDirectory}/GeoLite2-City.mmdb"
  ];
}
