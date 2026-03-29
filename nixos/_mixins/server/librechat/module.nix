{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.librechat;
  settingsFormat = pkgs.formats.yaml { };
in
{
  options.services.librechat = {
    enable = lib.mkEnableOption "LibreChat";

    package = lib.mkPackageOption pkgs "librechat" { };

    user = lib.mkOption {
      type = lib.types.str;
      default = "librechat";
      description = "User account under which LibreChat runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "librechat";
      description = "Group under which LibreChat runs.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "The host address to bind LibreChat to.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3080;
      description = "The port to run LibreChat on.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/librechat";
      description = "The data directory for LibreChat.";
    };

    mongoURI = lib.mkOption {
      type = lib.types.str;
      default = "mongodb://localhost/LibreChat";
      description = "MongoDB connection URI.";
    };

    enableLocalDB = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable and use a local MongoDB instance.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the firewall for LibreChat.";
    };

    environmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = ''
        List of environment files to load before starting LibreChat.
        These files should contain KEY=VALUE pairs.
        Sensitive values like API keys should be provided this way.
      '';
    };

    settings = lib.mkOption {
      type = settingsFormat.type;
      default = { };
      description = ''
        LibreChat configuration (librechat.yaml).
        See https://www.librechat.ai/docs/configuration/librechat_yaml for options.
      '';
      example = {
        version = "1.2.1";
        endpoints.anthropic = {
          titleConvo = true;
          titleModel = "claude-3-5-haiku-latest";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.mongodb.enable = lib.mkDefault cfg.enableLocalDB;

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
    };

    users.groups.${cfg.group} = { };

    systemd.services.librechat = {
      description = "LibreChat server";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network-online.target"
      ]
      ++ lib.optionals cfg.enableLocalDB [ "mongodb.service" ];
      wants = [ "network-online.target" ];
      environment = {
        HOME = cfg.dataDir;
        HOST = cfg.host;
        PORT = toString cfg.port;
        MONGO_URI = cfg.mongoURI;
      };
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.dataDir;
        StateDirectory = baseNameOf cfg.dataDir;
        EnvironmentFile = cfg.environmentFiles;
        ExecStart = "${cfg.package}/bin/librechat-server";
        Restart = "on-failure";
        RestartSec = 10;
        UMask = "0077";
        CapabilityBoundingSet = "";
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateMounts = true;
        PrivateTmp = true;
        PrivateUsers = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    environment.etc."librechat/librechat.yaml" = lib.mkIf (cfg.settings != { }) {
      source = settingsFormat.generate "librechat.yaml" cfg.settings;
      user = cfg.user;
      group = cfg.group;
      mode = "0440";
    };
  };
}
