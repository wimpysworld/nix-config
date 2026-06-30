{
  config,
  lib,
  noughtyLib,
  ...
}:
let
  username = config.noughty.user.name;
in
lib.mkIf (noughtyLib.isHost [ "malak" ] && config.services.gotosocial.enable) {
  services = {
    caddy = lib.mkIf config.services.caddy.enable {
      virtualHosts."goaccess.wimpys.world" = {
        extraConfig = ''
          encode zstd gzip
          root * /mnt/data/www/goaccess
          file_server browse
          basic_auth {
            ${username} $2a$14$aTTqvZOozMWiYBJ0IXkHxOiFuk0LeFHpt.7y0FPum4JO1v2u2KsJy
          }
        '';
        serverAliases = [
          "stats.wimpys.world"
        ];
      };
    };
    geoipupdate = {
      inherit (config.services.caddy) enable;
      settings = {
        AccountID = 1087490;
        EditionIDs = [
          "GeoLite2-ASN"
          "GeoLite2-City"
          "GeoLite2-Country"
        ];
        LicenseKey = {
          _secret = "${config.sops.secrets.maxmind_key.path}";
        };
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

  systemd.tmpfiles.rules = [
    "d /mnt/data/www/goaccess 0750 ${config.services.caddy.user} ${config.services.caddy.group}"
  ];
}
