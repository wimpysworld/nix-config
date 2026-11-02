{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  siloStateDir = "/var/lib/silo";
  # Port 8080 is used by llama-swap on inference hosts (including revan), so
  # bind Silo's web UI and API to 8090, matching upstream's default host port.
  siloPort = 8090;
  siloJellyfinPort = 8096;
  siloAudiobookshelfPort = 13378;
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

  networking.firewall.allowedTCPPorts = [
    siloPort
    siloJellyfinPort
    siloAudiobookshelfPort
  ];

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
    ];
    wants = [
      "network-online.target"
      "sops-nix.service"
    ];
    requires = [
      "postgresql.service"
      "postgresql-setup.service"
    ];
    wantedBy = [ "multi-user.target" ];

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
      install -d -m 0750 /tmp/silo-transcode /tmp/silo-download-artifacts
      install -d -m 0700 /tmp/silo-ebook-epub
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
        "silo/compat"
        "silo/compat/jellyfin-web"
        "silo/plugins"
        "silo/userdb"
      ];
      StateDirectoryMode = "0750";

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
      ReadWritePaths = [ "-/srv/pool" ];
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_NETLINK"
        "AF_UNIX"
      ];
    };
  };
}
