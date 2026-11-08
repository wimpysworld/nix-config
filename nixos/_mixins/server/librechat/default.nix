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
    runtimeInputs = [ pkgs.mongosh ];
    # Single-quoted strings in the mongosh --eval block are intentional
    # JavaScript, not shell expressions; disable shellcheck accordingly.
    checkPhase = "";
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

      mongosh --quiet "$mongoUri" --eval '
        const now = new Date();
        db.configs.updateOne(
          {
            principalType: "role",
            principalId: "ADMIN",
          },
          {
            $set: {
              principalType: "role",
              principalId: "ADMIN",
              principalModel: "Role",
              priority: 10,
              isActive: true,
              overrides: {
                mcpServers: {
                  "cloudflare-docs": {
                    type: "streamable-http",
                    url: "https://docs.mcp.cloudflare.com/mcp",
                    requiresOAuth: false,
                    chatMenu: true,
                    startup: true,
                  },
                  "cloudflare-api": {
                    type: "streamable-http",
                    url: "https://mcp.cloudflare.com/mcp",
                    headers: {
                      Authorization: "Bearer ''${CLOUDFLARE_API_TOKEN}",
                    },
                    requiresOAuth: false,
                    chatMenu: true,
                    startup: true,
                  },
                  context7: {
                    type: "streamable-http",
                    url: "https://mcp.context7.com/mcp",
                    headers: {
                      Authorization: "Bearer ''${CONTEXT7_API_KEY}",
                    },
                    requiresOAuth: false,
                    chatMenu: true,
                    startup: true,
                  },
                  linear: {
                    type: "streamable-http",
                    url: "https://mcp.linear.app/mcp",
                    headers: {
                      Authorization: "Bearer ''${LINEAR_API_KEY}",
                    },
                    requiresOAuth: false,
                    chatMenu: true,
                    startup: true,
                  },
                  nixos: {
                    type: "streamable-http",
                    url: "http://127.0.0.1:3081/mcp",
                    requiresOAuth: false,
                    chatMenu: true,
                    startup: true,
                  },
                },
              },
              updatedAt: now,
            },
            $setOnInsert: {
              createdAt: now,
            },
          },
          { upsert: true },
        );
      '
    '';
  };
in
{
  config = lib.mkIf (noughtyLib.hostHasTag "librechat") {
    environment.shellAliases.librechat-log = "journalctl _SYSTEMD_UNIT=librechat.service";

    sops.secrets.ANTHROPIC_API_KEY = {
      sopsFile = ../../../../secrets/ai.yaml;
      path = "/run/secrets/ANTHROPIC_API_KEY";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    sops.secrets.CONTEXT7_API_KEY = {
      sopsFile = ../../../../secrets/mcp.yaml;
      path = "/run/secrets/CONTEXT7_API_KEY";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    sops.secrets.LINEAR_API_KEY = {
      sopsFile = ../../../../secrets/linear.yaml;
      key = "wimpysworld";
      path = "/run/secrets/LINEAR_API_KEY";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    sops.secrets.CLOUDFLARE_API_TOKEN = lib.mkIf hasCloudflareSopsFile {
      sopsFile = cloudflareSopsFile;
      path = "/run/secrets/CLOUDFLARE_API_TOKEN";
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

    # Upstream's services.librechat.openFirewall references an undefined
    # cfg.port in nixpkgs ec942ba, so it throws when enabled. Leave it off and
    # open the firewall from env.PORT, matching the previous vendored module.
    networking.firewall.allowedTCPPorts = [
      (lib.toInt config.services.librechat.env.PORT)
    ];

    services.librechat = {
      enable = true;
      package = lib.mkDefault pkgs.librechat;
      meilisearch.enable = lib.mkDefault true;
      env = {
        ALLOW_EMAIL_LOGIN = lib.mkDefault true;
        ALLOWED_EMAIL_DOMAINS = lib.mkDefault "wimpress.org";
        ALLOW_REGISTRATION = lib.mkDefault false;
        ALLOW_SOCIAL_LOGIN = lib.mkDefault false;
        ALLOW_UNVERIFIED_EMAIL_LOGIN = lib.mkDefault true;
        HOST = lib.mkDefault "0.0.0.0";
        MONGO_URI = lib.mkIf (noughtyLib.hostHasTag "mongodb") (
          lib.mkDefault "mongodb://localhost:27017/librechat"
        );
      };
      credentials = {
        ANTHROPIC_API_KEY = config.sops.secrets.ANTHROPIC_API_KEY.path;
        CLOUDFLARE_API_TOKEN = lib.mkIf hasCloudflareSopsFile config.sops.secrets.CLOUDFLARE_API_TOKEN.path;
        CONTEXT7_API_KEY = config.sops.secrets.CONTEXT7_API_KEY.path;
        CREDS_IV = config.sops.secrets.CREDS_IV.path;
        CREDS_KEY = config.sops.secrets.CREDS_KEY.path;
        JWT_REFRESH_SECRET = config.sops.secrets.JWT_REFRESH_SECRET.path;
        JWT_SECRET = config.sops.secrets.JWT_SECRET.path;
        LINEAR_API_KEY = config.sops.secrets.LINEAR_API_KEY.path;
      };
      settings = lib.mkDefault {
        version = "1.3.6";
        endpoints.anthropic = {
          models = [ "claude-sonnet-5-5" ];
          titleConvo = true;
          titleModel = "claude-sonnet-5-5";
        };
        mcpSettings = {
          allowedAddresses = [
            "127.0.0.1"
            "127.0.0.1:3081"
          ];
        };
        mcpServers = {
          exa = {
            type = "streamable-http";
            url = "https://mcp.exa.ai/mcp?tools=web_search_exa,web_fetch_exa,web_search_advanced_exa";
            requiresOAuth = false;
            chatMenu = true;
            startup = true;
          };
        };
      };
    };

    services.meilisearch.masterKeyFile = lib.mkDefault config.sops.secrets.MEILI_MASTER_KEY.path;

    systemd.services.librechat-mcp-nixos = {
      description = "Local NixOS MCP server for LibreChat";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.nix ];
      environment = {
        FASTMCP_CHECK_FOR_UPDATES = "off";
        HOME = "/tmp";
        MCP_NIXOS_HOST = "127.0.0.1";
        MCP_NIXOS_PATH = "/mcp";
        MCP_NIXOS_PORT = "3081";
        MCP_NIXOS_TRANSPORT = "http";
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = lib.getExe pkgs.mcp-nixos;
        Restart = lib.mkDefault "always";
        RestartSec = lib.mkDefault 5;
        DynamicUser = true;
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

    systemd.services.librechat = {
      after = [
        "librechat-mcp-nixos.service"
      ]
      ++ lib.optionals (noughtyLib.hostHasTag "mongodb") [
        "mongodb.service"
        "librechat-provision-users.service"
      ];
      wants = [
        "librechat-mcp-nixos.service"
      ]
      ++ lib.optionals (noughtyLib.hostHasTag "mongodb") [
        "mongodb.service"
        "librechat-provision-users.service"
      ];
    };

    systemd.services.librechat-provision-users = lib.mkIf (noughtyLib.hostHasTag "mongodb") {
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
