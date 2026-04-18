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
  bondSopsFile = ../../../../secrets + "/hermes-bond.yaml";
  hermesSopsFile = ../../../../secrets + "/hermes.yaml";
  mcpSopsFile = ../../../../secrets + "/mcp.yaml";
  claudePackage = inputs.llm-agents.packages.${pkgs.system}.claude-code;
  codexPackage = inputs.llm-agents.packages.${pkgs.system}.codex;
  agentBrowserPackage = inputs.llm-agents.packages.${pkgs.system}.agent-browser;
  hermesHome = "${config.services.hermes-agent.stateDir}/.hermes";
  hermesAgentPackage = inputs.hermes-agent.packages.${pkgs.system}.default;
  hermesExtraPackages = with pkgs; [
    bat
    claudePackage
    codexPackage
    agentBrowserPackage
    curl
    fd
    ffmpeg
    findutils
    fzf
    gh
    git
    gnugrep
    gnused
    gnutar
    jq
    just
    lsof
    mawk
    nh
    nix-direnv
    nodejs-slim
    poppler-utils
    procps
    python3Minimal
    ripgrep
    sd
    tree
    unzip
    util-linux
    uv
    wget
    yq
  ];
  wrappedHermesBash = pkgs.runCommand "hermes-wrapped-bash" { } ''
    mkdir -p "$out/bin"

    cat > "$out/bin/bash" <<EOF
    #!${pkgs.bash}/bin/bash
    export PATH="$out/bin:${
      lib.makeBinPath (
        [
          pkgs.coreutils
          hermesAgentPackage
        ]
        ++ hermesExtraPackages
      )
    }"
    exec ${pkgs.bash}/bin/bash --noprofile --norc "\$@"
    EOF

    chmod 0555 "$out/bin/bash"
  '';
  username = config.noughty.user.name;
in
{
  imports = [
    inputs.hermes-agent.nixosModules.default
  ];

  config = lib.mkIf (noughtyLib.hostHasTag "hermes") {
    users.users.hermes.uid = 1984;
    users.users.hermes.packages = [
      wrappedHermesBash
      hermesAgentPackage
    ]
    ++ hermesExtraPackages;
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

      BOND_MD = {
        sopsFile = bondSopsFile;
        owner = "root";
        group = "root";
        mode = "0400";
      };

      ANTHROPIC_API_KEY = {
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

      GITHUB_TOKEN = {
        sopsFile = hermesSopsFile;
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };

    sops.templates."hermes-env" = {
      content = ''
        TELEGRAM_BOT_TOKEN=${config.sops.placeholder.TELEGRAM_BOT_TOKEN}
        TELEGRAM_ALLOWED_USERS=${config.sops.placeholder.TELEGRAM_ALLOWED_USERS}
        ANTHROPIC_API_KEY=${config.sops.placeholder.ANTHROPIC_API_KEY}
        CONTEXT7_API_KEY=${config.sops.placeholder.CONTEXT7_API_KEY}
        JINA_API_KEY=${config.sops.placeholder.JINA_API_KEY}
        GH_TOKEN=${config.sops.placeholder.GITHUB_TOKEN}
        GITHUB_TOKEN=${config.sops.placeholder.GITHUB_TOKEN}
        _HERMES_FORCE_TELEGRAM_BOT_TOKEN=${config.sops.placeholder.TELEGRAM_BOT_TOKEN}
        _HERMES_FORCE_ANTHROPIC_API_KEY=${config.sops.placeholder.ANTHROPIC_API_KEY}
        _HERMES_FORCE_CONTEXT7_API_KEY=${config.sops.placeholder.CONTEXT7_API_KEY}
        _HERMES_FORCE_JINA_API_KEY=${config.sops.placeholder.JINA_API_KEY}
        _HERMES_FORCE_GH_TOKEN=${config.sops.placeholder.GITHUB_TOKEN}
        _HERMES_FORCE_GITHUB_TOKEN=${config.sops.placeholder.GITHUB_TOKEN}
      '';
      owner = "root";
      group = "root";
      mode = "0400";
    };

    sops.templates."hermes-soul" = {
      content = ''
        ${builtins.readFile ./traya-soul.md}

        ${config.sops.placeholder.BOND_MD}
      '';
      owner = "root";
      group = "root";
      mode = "0644";
    };

    services.hermes-agent = {
      enable = true;
      addToSystemPackages = true;
      environment = {
        TELEGRAM_HOME_CHANNEL = "-1003933927882";
      };
      extraPackages = [
        wrappedHermesBash
        hermesAgentPackage
      ]
      ++ hermesExtraPackages;
      mcpServers = {
        exa = {
          url = "https://mcp.exa.ai/mcp";
        };
        context7 = {
          url = "https://mcp.context7.com/mcp";
          headers = {
            Authorization = "Bearer \${CONTEXT7_API_KEY}";
          };
        };
        nixos = {
          command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
          args = [ ];
        };
        cloudflare = {
          url = "https://docs.mcp.cloudflare.com/mcp";
        };
      };

      # Upstream seeds these into ${hermesHome}/auth.json and ${hermesHome}/.env.
      authFile = config.sops.secrets."hermes/auth".path;
      environmentFiles = [ config.sops.templates."hermes-env".path ];

      settings = {
        model = {
          default = "qwen3.5-35b-a3b";
          provider = "custom";
          context_length = 262144;
          base_url = "http://skrye.drongo-gamma.ts.net:8080/v1";
        };

        custom_providers = [
          {
            name = "zannah";
            base_url = "http://zannah.drongo-gamma.ts.net:8080/v1";
            model = "qwen3-coder-next";
            models = {
              qwen3-coder-next = {
                context_length = 262144;
              };
              "qwen3.5-35b-a3b" = {
                context_length = 262144;
              };
            };
          }
        ];

        terminal = {
          backend = "local";
          cwd = "/var/lib/hermes/workspace";
          timeout = 180;
          persistent_shell = true;
          env_passthrough = [
            "TERM"
            "COLORTERM"
          ];
        };

        providers = {
          anthropic = {
            allowed_models = [
              "claude-sonnet-4-6"
              "claude-opus-4-6"
            ];
          };
          openai-codex = {
            allowed_models = [ "gpt-5.4" ];
          };
        };

        fallback_model = {
          provider = "custom";
          model = "qwen3.5-35b-a3b";
          base_url = "http://zannah.drongo-gamma.ts.net:8080/v1";
        };

        memory = {
          memory_enabled = true;
          user_profile_enabled = true;
          provider = "holographic";
        };
      };
    };

    systemd.services.hermes-agent.path = lib.mkBefore [ wrappedHermesBash ];

    systemd.tmpfiles.rules = [
      "L+ ${hermesHome}/SOUL.md - - - - ${config.sops.templates."hermes-soul".path}"
    ];
  };
}
