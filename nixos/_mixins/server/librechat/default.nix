{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  aiSopsFile = ../../../../secrets/ai.yaml;
  dataDir = config.services.librechat.dataDir;
  secretDir = "${dataDir}/secrets";
  secretPath = name: "${secretDir}/${name}";
  librechatUser = config.services.librechat.user;
  librechatGroup = config.services.librechat.group;
in
lib.mkIf (noughtyLib.hostHasTag "librechat") {
  environment.shellAliases.librechat-log = "journalctl _SYSTEMD_UNIT=librechat.service";

  networking.firewall.allowedTCPPorts = lib.mkDefault [ config.services.librechat.env.PORT ];

  sops.secrets.ANTHROPIC_API_KEY = {
    sopsFile = aiSopsFile;
    owner = librechatUser;
    group = librechatGroup;
    mode = "0400";
  };

  services.librechat = {
    enable = true;
    enableLocalDB = lib.mkDefault true;
    env = {
      ALLOW_REGISTRATION = lib.mkDefault false;
      ENDPOINTS = lib.mkDefault "anthropic";
      HOST = lib.mkDefault "0.0.0.0";
      PORT = lib.mkDefault 3080;
    };
    credentials = {
      ANTHROPIC_API_KEY = config.sops.secrets.ANTHROPIC_API_KEY.path;
      CREDS_IV = secretPath "creds_iv";
      CREDS_KEY = secretPath "creds_key";
      JWT_REFRESH_SECRET = secretPath "jwt_refresh_secret";
      JWT_SECRET = secretPath "jwt_secret";
    };
    settings = lib.mkDefault {
      version = "1.2.1";
      endpoints.anthropic = {
        titleConvo = true;
        titleModel = "claude-3-5-haiku-latest";
      };
    };
  };

  systemd.services.librechat = {
    after = [ "librechat-secrets.service" ];
    wants = [ "librechat-secrets.service" ];
  };

  systemd.services.librechat-secrets = {
    description = "Generate local LibreChat application secrets";
    before = [ "librechat.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = librechatUser;
      Group = librechatGroup;
      StateDirectory = builtins.baseNameOf dataDir;
      UMask = "0077";
      WorkingDirectory = dataDir;
    };
    script = ''
      set -euo pipefail

      ${pkgs.coreutils}/bin/mkdir -p "${secretDir}"

      createSecret() {
        local path="$1"
        local bytes="$2"

        if [ ! -s "${"$"}path" ]; then
          ${pkgs.openssl}/bin/openssl rand -hex "${"$"}bytes" > "${"$"}path"
        fi

        ${pkgs.coreutils}/bin/chmod 0400 "${"$"}path"
      }

      createSecret "${secretPath "creds_key"}" 32
      createSecret "${secretPath "creds_iv"}" 16
      createSecret "${secretPath "jwt_secret"}" 32
      createSecret "${secretPath "jwt_refresh_secret"}" 32
    '';
  };
}
