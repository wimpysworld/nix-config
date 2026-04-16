{
  config,
  inputs,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  aiSopsFile = ../../../../secrets + "/ai.yaml";
  hermesSopsFile = ../../../../secrets + "/hermes.yaml";
  mcpSopsFile = ../../../../secrets + "/mcp.yaml";
  hermesHome = "${config.services.hermes-agent.stateDir}/.hermes";
  username = config.noughty.user.name;
in
{
  imports = [
    inputs.hermes-agent.nixosModules.default
  ];

  config = lib.mkIf (noughtyLib.hostHasTag "hermes") {
    users.users.hermes.uid = 1984;
    users.groups.hermes.gid = 1984;
    users.users.${username}.extraGroups = lib.mkAfter [ "hermes" ];

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

      TELEGRAM_ALLOWED_USERS = {
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
        TELEGRAM_ALLOWED_USERS=${config.sops.placeholder.TELEGRAM_ALLOWED_USERS}
        OPENAI_API_KEY=${config.sops.placeholder.OPENAI_API_KEY}
        CONTEXT7_API_KEY=${config.sops.placeholder.CONTEXT7_API_KEY}
        JINA_API_KEY=${config.sops.placeholder.JINA_API_KEY}
      '';
      owner = "root";
      group = "root";
      mode = "0400";
    };

    services.hermes-agent = {
      enable = true;
      addToSystemPackages = true;
      extraPackages = [ pkgs.gh ];

      # Upstream seeds these into ${hermesHome}/auth.json and ${hermesHome}/.env.
      authFile = config.sops.secrets."hermes/auth".path;
      environmentFiles = [ config.sops.templates."hermes-env".path ];

      settings = {
        model = {
          default = "qwen3.5-9b";
          provider = "custom";
          base_url = "http://127.0.0.1:8080/v1";
        };

        fallback_model = {
          provider = "openai-codex";
          model = "gpt-5.4";
        };

        memory = {
          memory_enabled = true;
          user_profile_enabled = true;
          provider = "holographic";
        };
      };
    };

    systemd.tmpfiles.rules = [
      "L+ ${hermesHome}/SOUL.md - - - - ${./traya-soul.md}"
    ];
  };
}
