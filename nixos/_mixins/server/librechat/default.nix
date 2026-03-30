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
  librechatProvisionUsers = pkgs.writeShellApplication {
    name = "librechat-provision-users";
    excludeShellCheckViolations = [ "SC2016" ];
    runtimeInputs = [ pkgs.mongosh ];
    text = ''
      mongoUri="mongodb://127.0.0.1:27017/librechat"

      : "''${HASH_MARTIN:?}"
      : "''${HASH_LOUISE:?}"
      : "''${HASH_AGATHA:?}"

      upsertUser() {
        local email="$1"
        local name="$2"
        local username="$3"
        local role="$4"
        local hashFile="$5"
        local passwordHash

        passwordHash="$(<"$hashFile")"

        EMAIL="$email" \
        NAME="$name" \
        USERNAME="$username" \
        ROLE="$role" \
        PASSWORD_HASH="$passwordHash" \
          mongosh --quiet "$mongoUri" --eval '
            const now = new Date();

            db.users.updateOne(
              { email: process.env.EMAIL },
              {
                $set: {
                  email: process.env.EMAIL,
                  name: process.env.NAME,
                  username: process.env.USERNAME,
                  password: process.env.PASSWORD_HASH,
                  provider: "local",
                  role: process.env.ROLE,
                  emailVerified: true,
                  avatar: null,
                  updatedAt: now,
                },
                $setOnInsert: {
                  createdAt: now,
                },
              },
              { upsert: true },
            );
          '
      }

      upsertUser "martin@wimpress.org" "Martin Wimpress" "martin" "ADMIN" "$HASH_MARTIN"
      upsertUser "louise@wimpress.org" "Louise Wimpress" "louise" "USER" "$HASH_LOUISE"
      upsertUser "agatha@wimpress.org" "Agatha Wimpress" "agatha" "USER" "$HASH_AGATHA"
    '';
  };
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
      owner = "root";
      group = "root";
      mode = "0400";
    };

    sops.secrets.CREDS_KEY = {
      sopsFile = ../../../../secrets/librechat.yaml;
      path = "/run/secrets/CREDS_KEY";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    sops.secrets.CREDS_IV = {
      sopsFile = ../../../../secrets/librechat.yaml;
      path = "/run/secrets/CREDS_IV";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    sops.secrets.JWT_SECRET = {
      sopsFile = ../../../../secrets/librechat.yaml;
      path = "/run/secrets/JWT_SECRET";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    sops.secrets.JWT_REFRESH_SECRET = {
      sopsFile = ../../../../secrets/librechat.yaml;
      path = "/run/secrets/JWT_REFRESH_SECRET";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    sops.secrets.MEILI_MASTER_KEY = {
      sopsFile = ../../../../secrets/librechat.yaml;
      path = "/run/secrets/MEILI_MASTER_KEY";
      owner = "root";
      group = "root";
      mode = "0440";
    };

    sops.secrets.USER_PW_MARTIN = {
      sopsFile = ../../../../secrets/librechat.yaml;
      owner = "root";
      group = "root";
      mode = "0400";
    };

    sops.secrets.USER_PW_LOUISE = {
      sopsFile = ../../../../secrets/librechat.yaml;
      owner = "root";
      group = "root";
      mode = "0400";
    };

    sops.secrets.USER_PW_AGATHA = {
      sopsFile = ../../../../secrets/librechat.yaml;
      owner = "root";
      group = "root";
      mode = "0400";
    };

    # Create the LibreChat tunnel in Cloudflare first, then encrypt the
    # tunnel token from the dashboard install connector flow into
    # secrets/cloudflare.yaml as CLOUDFLARE_TUNNEL_TOKEN_LIBRECHAT before
    # enabling the tunnel here.
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
        ALLOW_SOCIAL_LOGIN = lib.mkDefault false;
        ALLOW_UNVERIFIED_EMAIL_LOGIN = lib.mkDefault true;
        HOST = lib.mkDefault "0.0.0.0";
      };
      credentials = {
        ANTHROPIC_API_KEY = config.sops.secrets.ANTHROPIC_API_KEY.path;
        CREDS_IV = config.sops.secrets.CREDS_IV.path;
        CREDS_KEY = config.sops.secrets.CREDS_KEY.path;
        JWT_REFRESH_SECRET = config.sops.secrets.JWT_REFRESH_SECRET.path;
        JWT_SECRET = config.sops.secrets.JWT_SECRET.path;
      };
      settings = lib.mkDefault {
        version = "1.3.6";
        endpoints.anthropic = {
          models = [ "claude-sonnet-4-6-20260205" ];
          titleConvo = true;
          titleModel = "claude-haiku-4-5-20251001";
        };
      };
    };

    services.meilisearch.masterKeyFile = lib.mkDefault config.sops.secrets.MEILI_MASTER_KEY.path;

    systemd.services.librechat-provision-users = {
      description = "Provision initial LibreChat user accounts.";
      wantedBy = [ "multi-user.target" ];
      after = [ "mongodb.service" ];
      wants = [ "mongodb.service" ];
      environment = {
        HASH_MARTIN = config.sops.secrets.USER_PW_MARTIN.path;
        HASH_LOUISE = config.sops.secrets.USER_PW_LOUISE.path;
        HASH_AGATHA = config.sops.secrets.USER_PW_AGATHA.path;
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "root";
        ExecStart = lib.getExe librechatProvisionUsers;
      };
    };

    systemd.services.cloudflared-librechat = lib.mkIf hasCloudflareSopsFile {
      description = "Cloudflare Tunnel connector for LibreChat";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = lib.concatStringsSep " " [
          (lib.getExe pkgs.cloudflared)
          "tunnel"
          "--no-autoupdate"
          "run"
          "--token-file"
          config.sops.secrets.CLOUDFLARE_TUNNEL_TOKEN_LIBRECHAT.path
        ];
        Restart = lib.mkDefault "always";
        RestartSec = lib.mkDefault 5;
        User = lib.mkDefault "root";
        Group = lib.mkDefault "root";

        # Restrict the connector to outbound access and secret reads.
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectControlGroups = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
      };
    };

    # Remotely-managed tunnels store published application routing in
    # Cloudflare. Configure librechat.wimpys.world -> http://localhost:3080
    # in the Cloudflare dashboard or API for this tunnel.
  };
}
