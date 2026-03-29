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
        ANTHROPIC_API_KEY = config.sops.secrets.ANTHROPIC_API_KEY.path;
        CREDS_IV = config.sops.secrets.CREDS_IV.path;
        CREDS_KEY = config.sops.secrets.CREDS_KEY.path;
        JWT_REFRESH_SECRET = config.sops.secrets.JWT_REFRESH_SECRET.path;
        JWT_SECRET = config.sops.secrets.JWT_SECRET.path;
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
  };
}
