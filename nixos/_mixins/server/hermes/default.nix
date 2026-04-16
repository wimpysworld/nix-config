{
  config,
  inputs,
  lib,
  noughtyLib,
  ...
}:
let
  aiSopsFile = ../../../../secrets + "/ai.yaml";
  hermesSopsFile = ../../../../secrets + "/hermes.yaml";
  mcpSopsFile = ../../../../secrets + "/mcp.yaml";
  username = config.noughty.user.name;
in
{
  imports = [
    inputs.hermes-agent.nixosModules.default
  ];

  config = lib.mkIf (noughtyLib.hostHasTag "hermes") {
    sops.secrets = {
      "hermes/auth" = {
        sopsFile = ../../../../secrets/hermes-auth.json;
        format = "json";
        key = "";
        owner = "root";
        group = "root";
        mode = "0400";
      };

      TELEGRAM_BOT_TOKEN = {
        sopsFile = hermesSopsFile;
        owner = "root";
        group = "root";
        mode = "0400";
      };

      OPENAI_API_KEY = {
        sopsFile = aiSopsFile;
        owner = "root";
        group = "root";
        mode = "0400";
      };

      CONTEXT7_API_KEY = {
        sopsFile = mcpSopsFile;
        owner = "root";
        group = "root";
        mode = "0400";
      };

      JINA_API_KEY = {
        sopsFile = mcpSopsFile;
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };

    sops.templates."hermes-env" = {
      content = ''
        TELEGRAM_BOT_TOKEN=${config.sops.placeholder.TELEGRAM_BOT_TOKEN}
        OPENAI_API_KEY=${config.sops.placeholder.OPENAI_API_KEY}
        CONTEXT7_API_KEY=${config.sops.placeholder.CONTEXT7_API_KEY}
        JINA_API_KEY=${config.sops.placeholder.JINA_API_KEY}
      '';
      owner = "root";
      group = "root";
      mode = "0400";
    };

    virtualisation.docker.enable = lib.mkForce false;

    security.sudo.extraRules = [
      {
        users = [ username ];
        commands = [
          {
            command = "/run/current-system/sw/bin/podman";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    services.hermes-agent = {
      enable = true;
      addToSystemPackages = true;
      authFile = config.sops.secrets."hermes/auth".path;
      environmentFiles = [ config.sops.templates."hermes-env".path ];
      documents = {
        "SOUL.md" = builtins.readFile ./traya-soul.md;
      };

      container = {
        enable = true;
        backend = "podman";
        hostUsers = [ username ];
        extraOptions = [ "--network=host" ];
      };

      settings = {
        model = {
          default = "qwen3.5:9b";
          provider = "custom";
          base_url = "http://revan.drongo-gamma.ts.net:8080/v1";
        };

        fallback_model = {
          provider = "openai-codex";
          model = "gpt-5.4";
        };
      };
    };
  };
}
