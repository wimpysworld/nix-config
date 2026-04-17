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
  hermesAgentPackage = inputs.hermes-agent.packages.${pkgs.system}.default;
  hermesExtraPackages = with pkgs; [
    bat
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
    nodejs
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
    };

    sops.templates."hermes-env" = {
      content = ''
        TELEGRAM_BOT_TOKEN=${config.sops.placeholder.TELEGRAM_BOT_TOKEN}
        TELEGRAM_ALLOWED_USERS=${config.sops.placeholder.TELEGRAM_ALLOWED_USERS}
        ANTHROPIC_API_KEY=${config.sops.placeholder.ANTHROPIC_API_KEY}
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

    systemd.services.hermes-agent.path = lib.mkBefore [ wrappedHermesBash ];

    systemd.tmpfiles.rules = [
      "L+ ${hermesHome}/SOUL.md - - - - ${./traya-soul.md}"
    ];
  };
}
