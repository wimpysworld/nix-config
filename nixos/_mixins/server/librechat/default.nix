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
      environmentFiles = [
        "/var/lib/librechat/librechat.env"
      ];
      host = lib.mkDefault "0.0.0.0";
      openFirewall = lib.mkDefault true;
      package = lib.mkDefault pkgs.unstable.librechat;
      port = lib.mkDefault 3080;
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
      after = [
        "librechat-env.service"
        "librechat-secrets.service"
      ];
      wants = [
        "librechat-env.service"
        "librechat-secrets.service"
      ];
    };

    systemd.services.librechat-secrets = {
      description = "Generate local LibreChat application secrets";
      before = [ "librechat-env.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "librechat";
        Group = "librechat";
        StateDirectory = "librechat";
        UMask = "0077";
        WorkingDirectory = "/var/lib/librechat";
      };
      script = ''
        set -euo pipefail

        ${pkgs.coreutils}/bin/mkdir -p /var/lib/librechat/secrets

        createSecret() {
          local path="$1"
          local bytes="$2"

          if [ ! -s "$path" ]; then
            ${pkgs.openssl}/bin/openssl rand -hex "$bytes" > "$path"
          fi

          ${pkgs.coreutils}/bin/chmod 0400 "$path"
        }

        createSecret /var/lib/librechat/secrets/creds_key 32
        createSecret /var/lib/librechat/secrets/creds_iv 16
        createSecret /var/lib/librechat/secrets/jwt_secret 32
        createSecret /var/lib/librechat/secrets/jwt_refresh_secret 32
      '';
    };

    systemd.services.librechat-env = {
      description = "Assemble LibreChat environment file";
      before = [ "librechat.service" ];
      after = [ "librechat-secrets.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "librechat";
        Group = "librechat";
        StateDirectory = "librechat";
        UMask = "0077";
        WorkingDirectory = "/var/lib/librechat";
      };
      script = ''
        set -euo pipefail

        env_file=/var/lib/librechat/librechat.env
        tmp_file="$(${pkgs.coreutils}/bin/mktemp /var/lib/librechat/librechat.env.XXXXXX)"

        chmod 0600 "$tmp_file"

        {
          printf 'ALLOW_REGISTRATION=false\n'
          printf 'ALLOW_EMAIL_LOGIN=true\n'
          printf 'ALLOWED_EMAIL_DOMAINS=wimpress.org\n'
          printf 'EMAIL_HOST=localhost\n'
          printf 'EMAIL_PORT=25\n'
          printf 'EMAIL_ENCRYPTION=none\n'
          printf 'EMAIL_FROM=martin@wimpress.org\n'
          printf 'ANTHROPIC_API_KEY=%s\n' "$(${pkgs.coreutils}/bin/cat /run/secrets/ANTHROPIC_API_KEY)"
          printf 'CREDS_KEY=%s\n' "$(${pkgs.coreutils}/bin/cat /var/lib/librechat/secrets/creds_key)"
          printf 'CREDS_IV=%s\n' "$(${pkgs.coreutils}/bin/cat /var/lib/librechat/secrets/creds_iv)"
          printf 'JWT_SECRET=%s\n' "$(${pkgs.coreutils}/bin/cat /var/lib/librechat/secrets/jwt_secret)"
          printf 'JWT_REFRESH_SECRET=%s\n' "$(${pkgs.coreutils}/bin/cat /var/lib/librechat/secrets/jwt_refresh_secret)"
        } > "$tmp_file"

        ${pkgs.coreutils}/bin/mv "$tmp_file" "$env_file"
        ${pkgs.coreutils}/bin/chmod 0400 "$env_file"
      '';
    };
  };
}
