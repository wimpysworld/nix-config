{ config, hostname, lib, pkgs, tailNet, ... }:
let
  basePath = "/syncthing";
  # Only enables caddy if tailscale is enabled or the host is Malak
  useCaddy = if (config.services.tailscale.enable || lib.elem hostname [ "malak" ])
    then true else false;
in
{
  environment.systemPackages = with pkgs; [ custom-caddy ];
  services = {
    caddy = {
      enable = useCaddy;
      package = pkgs.custom-caddy;
      # Reverse proxy syncthing; which is configured/enabled via Home Manager
      virtualHosts."${hostname}.${tailNet}" = lib.mkIf config.services.tailscale.enable
      {
        extraConfig = ''
            redir ${basePath} ${basePath}/
            handle_path ${basePath}/* {
              reverse_proxy localhost:8384 {
                header_up Host localhost
              }
            }
          '';
        logFormat = lib.mkDefault ''
          output file /var/log/caddy/tailscale.log
        '';
      };
    };
  };

  systemd.services.goaccess-tailscale = {
    description = "Generate goaccess tailscale report";
    serviceConfig = {
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.goaccess}/bin/goaccess -f /var/log/caddy/tailscale.log --log-format=CADDY -o /mnt/data/www/goaccess/tailscale.html --persist --geoip-database=/var/lib/GeoIP/GeoLite2-City.mmdb'";
      User = "${config.services.caddy.user}";
    };
  };

  systemd.timers.goaccess-tailscale = {
    description = "Run goaccess tailscale report every hour";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "1h";
      RandomizedDelaySec = 300;
    };
  };
}
