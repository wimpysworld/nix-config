{
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  aiSopsFile = ../../../../secrets/ai.yaml;
  librechatDataDir = "/var/lib/librechat";
  librechatSecretsDir = "${librechatDataDir}/secrets";
  anthropicApiKeyPath = "/run/secrets/ANTHROPIC_API_KEY";
in
lib.mkIf (noughtyLib.hostHasTag "librechat") {
  environment.shellAliases.librechat-log = "journalctl _SYSTEMD_UNIT=librechat.service";

  networking.firewall.allowedTCPPorts = lib.mkDefault [ 3080 ];

  sops.secrets.ANTHROPIC_API_KEY = {
    sopsFile = aiSopsFile;
    path = anthropicApiKeyPath;
    owner = "librechat";
    group = "librechat";
    mode = "0400";
  };

  services.mongodb.enable = lib.mkDefault true;

  systemd.tmpfiles.rules = [
    "d ${librechatDataDir} 0750 librechat librechat"
    "d ${librechatSecretsDir} 0700 librechat librechat"
  ];

  systemd.services.librechat = {
    description = "LibreChat server";
    wantedBy = [ "multi-user.target" ];
    after = [
      "mongodb.service"
      "librechat-secrets.service"
      "network-online.target"
    ];
    wants = [
      "mongodb.service"
      "librechat-secrets.service"
      "network-online.target"
    ];
    environment = {
      ALLOW_REGISTRATION = lib.mkDefault "false";
      ENDPOINTS = lib.mkDefault "anthropic";
      HOST = lib.mkDefault "0.0.0.0";
      HOME = librechatDataDir;
      MONGO_URI = lib.mkDefault "mongodb://127.0.0.1:27017/LibreChat";
      PORT = lib.mkDefault "3080";
    };
    serviceConfig = {
      Type = "simple";
      User = "librechat";
      Group = "librechat";
      WorkingDirectory = librechatDataDir;
      Restart = "on-failure";
      RestartSec = 10;
      StateDirectory = "librechat";
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
    script = ''
      set -euo pipefail

      export ANTHROPIC_API_KEY="$(${pkgs.coreutils}/bin/cat ${anthropicApiKeyPath})"
      export CREDS_KEY="$(${pkgs.coreutils}/bin/cat ${librechatSecretsDir}/creds_key)"
      export CREDS_IV="$(${pkgs.coreutils}/bin/cat ${librechatSecretsDir}/creds_iv)"
      export JWT_SECRET="$(${pkgs.coreutils}/bin/cat ${librechatSecretsDir}/jwt_secret)"
      export JWT_REFRESH_SECRET="$(${pkgs.coreutils}/bin/cat ${librechatSecretsDir}/jwt_refresh_secret)"

      exec ${pkgs.librechat}/bin/librechat-server
    '';
  };

  systemd.services.librechat-secrets = {
    description = "Generate local LibreChat application secrets";
    before = [ "librechat.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "librechat";
      Group = "librechat";
      StateDirectory = "librechat";
      UMask = "0077";
      WorkingDirectory = librechatDataDir;
    };
    script = ''
      set -euo pipefail

      ${pkgs.coreutils}/bin/mkdir -p "${librechatSecretsDir}"

      createSecret() {
        local path="$1"
        local bytes="$2"

        if [ ! -s "$path" ]; then
          ${pkgs.openssl}/bin/openssl rand -hex "$bytes" > "$path"
        fi

        ${pkgs.coreutils}/bin/chmod 0400 "$path"
      }

      createSecret "${librechatSecretsDir}/creds_key" 32
      createSecret "${librechatSecretsDir}/creds_iv" 16
      createSecret "${librechatSecretsDir}/jwt_secret" 32
      createSecret "${librechatSecretsDir}/jwt_refresh_secret" 32
    '';
  };

  users.groups.librechat = { };

  users.users.librechat = {
    isSystemUser = true;
    group = "librechat";
    home = librechatDataDir;
    createHome = true;
    description = "LibreChat server user";
  };
}
