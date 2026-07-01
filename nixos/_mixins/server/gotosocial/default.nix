{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  gotosocial-backup = pkgs.writeShellApplication {
    name = "gotosocial-backup";
    runtimeInputs = with pkgs; [
      gnugrep
      gotosocial
      gzip
      openssl
      rsync
      sqlite
      coreutils
      findutils
    ];
    text = builtins.readFile ./gotosocial-backup.sh;
  };
in
lib.mkMerge [
  (lib.mkIf (noughtyLib.isHost [ "malak" ]) {
    environment = {
      shellAliases = {
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
            # https://docs.gotosocial.org/en/latest/advanced/healthchecks/
            handle /livez {
              respond 403
            }
            handle /readyz {
              respond 403
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
          accounts-allow-custom-css = true;
          accounts-custom-css-length = 16384;
          advanced-rate-limit-exceptions = [
            "62.31.16.153/29"
            "80.209.186.64/28"
          ];
          bind-address = "127.0.0.1";
          db-type = "sqlite";
          # https://docs.gotosocial.org/en/latest/advanced/replicating-sqlite/
          db-sqlite-journal-mode = "WAL";
          db-sqlite-synchronous = "NORMAL";
          media-emoji-local-max-size = "200KiB";
          media-emoji-remote-max-size = "200KiB";
          host = "wimpysworld.social";
          instance-expose-public-timeline = true;
          instance-inject-mastodon-version = true;
          instance-languages = [ "en" ];
          landing-page-user = "martin";
          letsencrypt-enabled = false;
          media-description-max-chars = 1500;
          media-ffmpeg-pool-size = 1;
          port = 8282;
          statuses-max-chars = 1000;
          statuses-media-max-files = 5;
          statuses-poll-max-options = 5;
          storage-local-base-path = "/mnt/data/gotosocial/storage";
        };
      };
    };

    systemd.tmpfiles.rules = [
      "d /mnt/data/gotosocial           0755 gotosocial gotosocial"
      "d /mnt/data/gotosocial/storage   0755 gotosocial gotosocial"
    ];
  })

  # The local backup job runs only on malak. The migration target, cognus, will
  # send backups off-box to R2, so keep this file-based backup tied to malak and
  # separate from the service definition, which may move hosts.
  (lib.mkIf (noughtyLib.isHost [ "malak" ]) {
    environment.systemPackages = [
      gotosocial-backup
    ];

    sops.secrets.gotosocial-backup = {
      group = "root";
      mode = "0640";
      owner = "root";
      path = "/etc/gotosocial-backup.conf";
      sopsFile = ../../../../secrets/gotosocial-backup.yaml;
    };

    systemd.services.gotosocial-backup = {
      description = "Backup GotoSocial database and local media";
      serviceConfig = {
        ExecStart = "${pkgs.bash}/bin/bash -c '${gotosocial-backup}/bin/gotosocial-backup'";
        User = "root";
      };
    };

    systemd.timers.gotosocial-backup = {
      description = "Run GotoSocial backup every 4 hours";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "4h";
        RandomizedDelaySec = 300;
      };
    };
  })

  # Prepare cognus, the migration target, without touching the live malak host.
  # The GoToSocial database lives on a dedicated volume mounted at
  # /var/lib/gotosocial, so the service must wait for that mount before it
  # starts, or it would write the database to the root disk instead.
  (lib.mkIf (noughtyLib.isHost [ "cognus" ]) {
    systemd.services.gotosocial.unitConfig.RequiresMountsFor = "/var/lib/gotosocial";
  })
]
