{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  hasInference = noughtyLib.hostHasTag "inference";
  psql = "${config.services.postgresql.package}/bin/psql";
  siloStateDir = "/var/lib/silo";
  # Port 8080 is used by llama-swap on inference hosts (including revan), so
  # bind Silo's web UI and API to 8090, matching upstream's default host port.
  siloPort = 8090;
  siloJellyfinPort = 8096;
  siloAudiobookshelfPort = 13378;
  llamaSwapProviderId = "custom-llama-swap";
  llamaSwapEmbeddingModel = "qwen3-embedding-0.6b";
  llamaSwapProvidersJson = builtins.toJSON {
    version = 2;
    providers = [
      {
        id = llamaSwapProviderId;
        type = "custom";
        name = "llama-swap";
        base_url = "http://127.0.0.1:8080/v1";
        capabilities = [
          "chat"
          "embeddings"
        ];
      }
    ];
  };
in
lib.mkIf (noughtyLib.hostHasTag "silo") {
  assertions = [
    {
      assertion = noughtyLib.hostHasTag "postgres";
      message = "The silo server mixin requires the postgres host tag.";
    }
  ];

  environment = {
    shellAliases.silo-log = "journalctl _SYSTEMD_UNIT=silo.service";
    systemPackages = [ pkgs.silo-server ];
  };

  fonts = {
    fontconfig.enable = true;
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
    ];
  };

  networking.firewall = {
    allowedTCPPorts = [
      siloPort
      siloJellyfinPort
      siloAudiobookshelfPort
    ];
    allowedUDPPorts = [
      1900
      5353
      7359
    ];
  };

  programs.nix-ld.enable = true;

  sops = {
    secrets.SILO_SECRET_KEY = {
      sopsFile = ../../../../secrets/silo.yaml;
      owner = "root";
      group = "root";
      mode = "0400";
    };

    templates."silo.env" = {
      content = ''
        SECRET_KEY=${config.sops.placeholder.SILO_SECRET_KEY}
      '';
      owner = "silo";
      group = "silo";
      mode = "0400";
      restartUnits = [ "silo.service" ];
    };
  };

  users.users.silo = {
    isSystemUser = true;
    group = "silo";
    home = siloStateDir;
    extraGroups = [
      "render"
      "users"
      "video"
    ];
    description = "Silo media server";
  };
  users.groups.silo = { };

  systemd.services.silo = {
    description = "Silo media server";
    after = [
      "network-online.target"
      "postgresql.service"
      "postgresql-setup.service"
      "sops-nix.service"
      "srv-pool.mount"
    ]
    ++ lib.optional hasInference "llama-swap.service";
    wants = [
      "network-online.target"
      "sops-nix.service"
    ]
    ++ lib.optional hasInference "llama-swap.service";
    requires = [
      "postgresql.service"
      "postgresql-setup.service"
    ];
    wantedBy = [ "multi-user.target" ];

    unitConfig = {
      RequiresMountsFor = [ "/srv/pool" ];
      ConditionPathIsMountPoint = "/srv/pool";
    };

    path = lib.optional config.noughty.host.gpu.hasNvidia config.hardware.nvidia.package.bin;

    environment = {
      ABS_PORT = toString siloAudiobookshelfPort;
      DATABASE_URL = "postgres://silo@/silo?host=/run/postgresql&sslmode=disable";
      HOME = siloStateDir;
      JF_PORT = toString siloJellyfinPort;
      MODE = "integrated";
      PORT = toString siloPort;
      POSTGRES_TUNE = "off";
      SILO_PLUGIN_CACHE_DIR = "${siloStateDir}/plugins";
      XDG_CACHE_HOME = "/var/cache/silo";
    };

    preStart = ''
      install -d -m 0750 /tmp/silo-transcode
      install -d -m 0700 /tmp/silo-ebook-epub
    ''
    + lib.optionalString hasInference ''
      if [ "$(${psql} -h /run/postgresql -d silo --no-psqlrc -tAc "SELECT to_regclass('public.server_settings') IS NOT NULL;")" != "t" ]; then
        ${lib.getExe pkgs.silo-server} --migrate-only
      fi
      ${psql} -h /run/postgresql -d silo --no-psqlrc -v ON_ERROR_STOP=1 <<'SQL'
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1
          FROM public.server_settings
          WHERE key IN (
            'ai.providers',
            'recommendations.enabled',
            'recommendations.embedding_provider_id',
            'ai.text_provider_id',
            'ai.speech_provider_id'
          )
            AND length(value) > 0
        ) THEN
          INSERT INTO public.server_settings (key, value)
          VALUES
            ('ai.providers', '${llamaSwapProvidersJson}'),
            ('recommendations.embedding_provider_id', '${llamaSwapProviderId}'),
            ('recommendations.embedding_model', '${llamaSwapEmbeddingModel}'),
            ('recommendations.enabled', 'true')
          ON CONFLICT (key) DO UPDATE
            SET value = EXCLUDED.value
            WHERE length(public.server_settings.value) = 0;
        END IF;
      END
      $$;
      SQL
    '';

    serviceConfig = {
      Type = "simple";
      User = "silo";
      Group = "silo";
      SupplementaryGroups = [
        "render"
        "users"
        "video"
      ];
      WorkingDirectory = siloStateDir;
      EnvironmentFile = config.sops.templates."silo.env".path;
      ExecStart = lib.getExe pkgs.silo-server;
      Restart = "on-failure";
      RestartSec = 5;
      TimeoutStopSec = "2m";

      CacheDirectory = "silo";
      CacheDirectoryMode = "0750";
      StateDirectory = [
        "silo"
        "silo/artwork"
        "silo/backups"
        "silo/compat"
        "silo/compat/jellyfin-web"
        "silo/download-artifacts"
        "silo/plugins"
        "silo/userdb"
      ];
      StateDirectoryMode = "0750";
      BindPaths = [ "${siloStateDir}/download-artifacts:/tmp/silo-download-artifacts" ];

      # Hardening while preserving GPU device access (/dev/dri, /dev/nvidia*)
      # for VA-API, QSV, and NVENC hardware transcoding and /srv/pool access.
      NoNewPrivileges = true;
      PrivateDevices = false;
      PrivateTmp = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectSystem = "strict";
      ReadOnlyPaths = [ "/srv/pool" ];
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_NETLINK"
        "AF_UNIX"
      ];
    };
  };
}
