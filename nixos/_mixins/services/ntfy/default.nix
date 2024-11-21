{ config, hostname, lib, pkgs, tailNet, ... }:
let
  installOn = [ "malak" ];
in
lib.mkIf (lib.elem hostname installOn) {
  environment = {
    shellAliases = {
      goaccess-ntfy = "sudo ${pkgs.goaccess}/bin/goaccess -f /var/log/caddy/ntfy.log --log-format=CADDY --geoip-database=/var/lib/GeoIP/GeoLite2-City.mmdb";
      ntfy-log = "journalctl _SYSTEMD_UNIT=ntfy-sh.service";
    };
    systemPackages = with pkgs; [
      ntfy-sh
    ];
  };
  sops = {
    secrets = {
      ntfy-alert-env = {
        group = "root";
        mode = "0644";
        owner = "root";
        path = "/etc/ntfy-alert.env";
        sopsFile = ../../../../secrets/ntfy-alert.yaml;
      };
    };
  };
  services = {
    # https://docs.ntfy.sh/config/#__tabbed_11_4
    # https://blog.alexsguardian.net/posts/2023/09/12/selfhosting-ntfy/
    caddy = {
      virtualHosts."ntfy.wimpys.world" = {
        extraConfig = lib.mkIf config.services.ntfy-sh.enable ''
          reverse_proxy localhost:2586
          @httpget {
            protocol http
            method GET
            path_regexp ^/([-_a-z0-9]{0,64}$|docs/|static/)
          }
          redir @httpget https://{host}{uri}
        '';
        logFormat = lib.mkDefault ''
          output file /var/log/caddy/ntfy.log
        '';
      };
    };
    ntfy-sh = {
      enable = true;
      settings = {
        attachment-cache-dir = "/var/lib/ntfy-sh/attachments";
        auth-default-access = "deny-all";
        auth-file = "/var/lib/ntfy-sh/user.db";
        base-url = "https://ntfy.wimpys.world";
        behind-proxy = true;
        cache-file = "/var/lib/ntfy-sh/cache-file.db";
        enable-login = true;
        #https://docs.ntfy.sh/config/#ios-instant-notifications
        upstream-base-url = "https://ntfy.sh";
      };
    };
  };

  systemd.services.goaccess-ntfy = {
    description = "Generate goaccess ntfy report";
    serviceConfig = {
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.goaccess}/bin/goaccess -f /var/log/caddy/ntfy.log --log-format=CADDY -o /mnt/data/www/goaccess/ntfy.html --persist --geoip-database=/var/lib/GeoIP/GeoLite2-City.mmdb'";
      User = "${config.services.caddy.user}";
    };
  };

  systemd.timers.goaccess-ntfy = {
    description = "Run goaccess ntfy report every hour";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "1h";
      RandomizedDelaySec = 300;
    };
  };
}
