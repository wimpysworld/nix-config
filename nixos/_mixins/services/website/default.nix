{ config, hostname, lib, pkgs, username, ... }:
let
  installOn = [ "malak" ];
in
lib.mkIf (lib.elem hostname installOn) {
  environment = {
    shellAliases = {
      goaccess-hugo = "sudo ${pkgs.goaccess}/bin/goaccess -f /var/log/caddy/hugo.log --log-format=CADDY --geoip-database=/var/lib/GeoIP/GeoLite2-City.mmdb";
      goaccess-littlelink = "sudo ${pkgs.goaccess}/bin/goaccess -f /var/log/caddy/littlelink.log --log-format=CADDY --geoip-database=/var/lib/GeoIP/GeoLite2-City.mmdb";
      goaccess-ip = "sudo ${pkgs.goaccess}/bin/goaccess -f /var/log/caddy/littlelink.log --log-format=CADDY --geoip-database=/var/lib/GeoIP/GeoLite2-City.mmdb";
    };
    systemPackages = with pkgs; [
      caddy
    ];
  };
  services = {
    caddy = {
      # The website
      virtualHosts."wimpysworld.com" = {
        extraConfig = ''
          encode zstd gzip
          root * /mnt/data/www/hugo
          file_server
          handle_errors {
            rewrite * /{err.status_code}.html
            file_server
          }
        '';
        logFormat = lib.mkDefault ''
          output file /var/log/caddy/hugo.log
        '';
        serverAliases = [
          "flexion.org"
          "wimpress.co.uk"
          "wimpress.com"
          "wimpress.io"
          "wimpress.org"
          "wimpysworld.net"
          "wimpysworld.org"
          "wimpys.world"
        ];
      };
      # LittleLinks and Vanity URLs
      virtualHosts."wimpysworld.link" = {
        extraConfig = ''
          encode zstd gzip
          root * /mnt/data/www/littlelink
          file_server
          redir /bluesky https://bsky.app/profile/wimpys.world temporary
          redir /discord https://discord.gg/vUsydfP temporary
          redir /facebook https://social.wimpys.world/@martin temporary
          redir /gaming https://www.youtube.com/channel/UC6D0aBP5pnWTGhQAvEmhUNw temporary
          redir /gaming-subscribe https://www.youtube.com/channel/UC6D0aBP5pnWTGhQAvEmhUNw?sub_confirmation=1 temporary
          redir /github https://github.com/wimpysworld/ temporary
          redir /insta https://www.instagram.com/wimpysworld temporary
          redir /instagram https://www.instagram.com/wimpysworld temporary
          redir /kit https://kit.co/wimpysworld temporary
          redir /lbry https://lbry.tv/@WimpysWorld:5 temporary
          redir /linkedin https://www.linkedin.com/in/martinwimpress/ temporary
          redir /mastodon https://fosstodon.org/@wimpy temporary
          redir /patreon https://www.patreon.com/wimpysworld temporary
          redir /social https://social.wimpys.world temporary
          redir /steam https://steamcommunity.com/id/wimpress/ temporary
          redir /telegram https://t.me/WimpysWorld temporary
          redir /tip https://streamelements.com/wimpysworld-2316/tip temporary
          redir /twitch https://www.twitch.tv/WimpysWorld temporary
          redir /twitter https://fosstodon.org/@wimpy temporary
          redir /website https://wimpysworld.com temporary
          redir /youtube-subscribe https://www.youtube.com/channel/UChpYmMp7EFaxuogUX1eAqyw?sub_confirmation=1 temporary
          redir /youtube https://www.youtube.com/channel/UChpYmMp7EFaxuogUX1eAqyw temporary
          handle_errors {
            redir * https://{http.request.host} temporary
            file_server
          }
        '';
        logFormat = lib.mkDefault ''
          output file /var/log/caddy/littlelink.log
        '';
        serverAliases = [
          "links.wimpys.world"
          "wimpysworld.info"
          "wimpysworld.io"
        ];
      };
      # Strip the www. and redirect to the apex domain
      # https://caddyserver.com/docs/caddyfile/patterns#redirect-www-subdomain
      virtualHosts."www.wimpysworld.com" = {
        extraConfig = ''
          redir https://{labels.1}.{labels.0}{uri} permanent
        '';
        logFormat = lib.mkDefault ''
          output file /var/log/caddy/hugo.log
        '';
        serverAliases = [
          "www.flexion.org"
          "www.wimpress.com"
          "www.wimpress.io"
          "www.wimpress.org"
          "www.wimpysworld.net"
          "www.wimpysworld.org"
          "www.wimpys.world"
        ];
      };
      virtualHosts."www.wimpress.co.uk" = {
        extraConfig = ''
          redir https://{labels.2}.{labels.1}.{labels.0}{uri} permanent
        '';
        logFormat = lib.mkDefault ''
          output file /var/log/caddy/hugo.log
        '';
      };
      virtualHosts."www.wimpysworld.link" = {
        extraConfig = ''
          redir https://{labels.1}.{labels.0}{uri} permanent
          log {
            output file /var/log/caddy/littlelink.log
          }
        '';
        logFormat = lib.mkDefault ''
          output file /var/log/caddy/littlelink.log
        '';
        serverAliases = [
          "www.wimpysworld.info"
          "www.wimpysworld.io"
        ];
      };
      # What is my IP?
      # - https://www.zellysnyder.com/posts/caddy-what-is-my-ip-service/
      virtualHosts."ip.wimpysworld.com" = {
        extraConfig = ''
          respond * 200 {
            body "{http.request.header.CF-Connecting-IP}"
            close
          }
        '';
        logFormat = lib.mkDefault ''
          output file /var/log/caddy/ip.log
        '';
        serverAliases = [
          "ip.flexion.org"
          "ip.wimpress.co.uk"
          "ip.wimpress.com"
          "ip.wimpress.io"
          "ip.wimpress.org"
          "ip.wimpysworld.info"
          "ip.wimpysworld.io"
          "ip.wimpysworld.link"
          "ip.wimpysworld.live"
          "ip.wimpysworld.net"
          "ip.wimpysworld.org"
          "ip.wimpysworld.social"
          "ip.wimpys.world"
        ];
      };
    };
  };

  systemd.services.goaccess-hugo = {
    description = "Generate goaccess hugo report";
    serviceConfig = {
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.goaccess}/bin/goaccess -f /var/log/caddy/hugo.log --log-format=CADDY -o /mnt/data/www/goaccess/hugo.html --persist --geoip-database=/var/lib/GeoIP/GeoLite2-City.mmdb'";
      User = "${config.services.caddy.user}";
    };
  };
  systemd.timers.goaccess-hugo = {
    description = "Run goaccess hugo report every hour";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "1h";
      RandomizedDelaySec = 300;
    };
  };

  systemd.services.goaccess-ip = {
    description = "Generate goaccess ip report";
    serviceConfig = {
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.goaccess}/bin/goaccess -f /var/log/caddy/ip.log --log-format=CADDY -o /mnt/data/www/goaccess/ip.html --persist --geoip-database=/var/lib/GeoIP/GeoLite2-City.mmdb'";
      User = "${config.services.caddy.user}";
    };
  };
  systemd.timers.goaccess-ip = {
    description = "Run goaccess ip every hour";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "1h";
      RandomizedDelaySec = 300;
    };
  };

  systemd.services.goaccess-littlelink = {
    description = "Generate goaccess littlelink report";
    serviceConfig = {
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.goaccess}/bin/goaccess -f /var/log/caddy/littlelink.log --log-format=CADDY -o /mnt/data/www/goaccess/littlelink.html --persist --geoip-database=/var/lib/GeoIP/GeoLite2-City.mmdb'";
      User = "${config.services.caddy.user}";
    };
  };
  systemd.timers.goaccess-littlelink = {
    description = "Run goaccess littlelink report every hour";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "1h";
      RandomizedDelaySec = 300;
    };
  };

  systemd.tmpfiles.rules = [
    "d /mnt/data/www/hugo       0755 ${username} users"
    "d /mnt/data/www/littlelink 0755 ${username} users"
  ];
}
