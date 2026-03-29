{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  cloudflareSopsFile = ../../../../secrets + "/cloudflare.yaml";
  hasCloudflareSopsFile = builtins.pathExists cloudflareSopsFile;
  librechatSecretsDir = "/var/lib/librechat/secrets";
in
{
  imports = [
    ./module.nix
  ];

  config = lib.mkIf (noughtyLib.hostHasTag "librechat") {
    environment.shellAliases.librechat-log = "journalctl _SYSTEMD_UNIT=librechat.service";

    sops.secrets.ANTHROPIC_API_KEY = {
      sopsFile = ../../../../secrets/ai.yaml;
      path = "/run/secrets/ANTHROPIC_API_KEY";
      owner = "librechat";
      group = "librechat";
      mode = "0400";
    };

    sops.secrets.MEILI_MASTER_KEY = {
      sopsFile = ../../../../secrets/ai.yaml;
      path = "/run/secrets/MEILI_MASTER_KEY";
      owner = "meilisearch";
      group = "meilisearch";
      mode = "0400";
    };

    # Create the LibreChat tunnel in Cloudflare first, then encrypt the
    # downloaded tunnel credentials JSON into secrets/cloudflare.yaml as
    # CLOUDFLARE_TUNNEL_TOKEN_LIBRECHAT before enabling the tunnel here.
    sops.secrets.CLOUDFLARE_TUNNEL_TOKEN_LIBRECHAT = lib.mkIf hasCloudflareSopsFile {
      sopsFile = cloudflareSopsFile;
      path = "/run/secrets/CLOUDFLARE_TUNNEL_TOKEN_LIBRECHAT";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    services.librechat = {
      enable = true;
      enableLocalDB = lib.mkDefault true;
      package = lib.mkDefault pkgs.unstable.librechat;
      openFirewall = lib.mkDefault true;
      meilisearch.enable = lib.mkDefault true;
      env = {
        ALLOW_EMAIL_LOGIN = lib.mkDefault true;
        ALLOWED_EMAIL_DOMAINS = lib.mkDefault "wimpress.org";
        ALLOW_REGISTRATION = lib.mkDefault false;
        EMAIL_ENCRYPTION = lib.mkDefault "none";
        EMAIL_FROM = lib.mkDefault "martin@wimpress.org";
        EMAIL_HOST = lib.mkDefault "localhost";
        EMAIL_PORT = lib.mkDefault 25;
        HOST = lib.mkDefault "0.0.0.0";
      };
      credentials = {
        ANTHROPIC_API_KEY = "/run/secrets/ANTHROPIC_API_KEY";
        CREDS_IV = "${librechatSecretsDir}/creds_iv";
        CREDS_KEY = "${librechatSecretsDir}/creds_key";
        JWT_REFRESH_SECRET = "${librechatSecretsDir}/jwt_refresh_secret";
        JWT_SECRET = "${librechatSecretsDir}/jwt_secret";
      };
      settings = lib.mkDefault {
        version = "1.3.6";
        endpoints.anthropic = {
          models = {
            default = [ "claude-sonnet-4-6-20260205" ];
            fetch = true;
          };
          titleConvo = true;
          titleModel = "claude-haiku-4-5-20251001";
        };
      };
    };

    services.meilisearch.masterKeyFile = config.sops.secrets.MEILI_MASTER_KEY.path;

    services.cloudflared = lib.mkIf hasCloudflareSopsFile {
      enable = true;
      tunnels.librechat = {
        credentialsFile = config.sops.secrets.CLOUDFLARE_TUNNEL_TOKEN_LIBRECHAT.path;
        default = "http_status:404";
        ingress."librechat.wimpys.world" = {
          service = "http://localhost:3080";
          originRequest.httpHostHeader = "librechat.wimpys.world";
        };
      };
    };

    systemd.services.librechat = {
      after = [ "librechat-secrets.service" ];
      wants = [ "librechat-secrets.service" ];
    };

    systemd.services.librechat-secrets = {
      description = "Generate local LibreChat application secrets";
      before = [
        "librechat.service"
      ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        UMask = "0077";
        WorkingDirectory = "/var/lib/librechat";
      };
      script = ''
        set -euo pipefail

        ${pkgs.coreutils}/bin/mkdir -p "${librechatSecretsDir}"
        ${pkgs.coreutils}/bin/chown root:root "${librechatSecretsDir}"
        ${pkgs.coreutils}/bin/chmod 0700 "${librechatSecretsDir}"

        createSecret() {
          local path="$1"
          local bytes="$2"
          local owner="$3"
          local group="$4"
          local mode="$5"

          if [ ! -s "$path" ]; then
            ${pkgs.openssl}/bin/openssl rand -hex "$bytes" > "$path"
          fi

          ${pkgs.coreutils}/bin/chown "$owner:$group" "$path"
          ${pkgs.coreutils}/bin/chmod "$mode" "$path"
        }

        createSecret "${librechatSecretsDir}/creds_key" 32 root root 0400
        createSecret "${librechatSecretsDir}/creds_iv" 16 root root 0400
        createSecret "${librechatSecretsDir}/jwt_secret" 32 root root 0400
        createSecret "${librechatSecretsDir}/jwt_refresh_secret" 32 root root 0400
      '';
    };
  };
}
