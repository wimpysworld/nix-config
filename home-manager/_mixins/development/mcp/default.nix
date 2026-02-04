{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux isDarwin;
  installFor = [ "martin" ];
  mcpSopsFile = ../../../../secrets/mcp.yaml;
  vscodeUserDir =
    if isLinux then
      "${config.xdg.configHome}/Code/User"
    else if isDarwin then
      "/Users/${username}/Library/Application Support/Code/User"
    else
      throw "Unsupported platform";

  # MCP server definitions
  # Uses config.sops.placeholder to inject secrets at activation time
  mcpServers = {
    # Servers without secrets
    cloudflare = {
      type = "http";
      url = "https://docs.mcp.cloudflare.com/mcp";
    };
    exa = {
      type = "http";
      url = "https://mcp.exa.ai/mcp";
    };
    nixos = {
      type = "stdio";
      command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
    };
    svelte = {
      type = "http";
      url = "https://mcp.svelte.dev/mcp";
    };
    # Servers with secrets
    context7 = {
      type = "http";
      url = "https://mcp.context7.com/mcp";
      headers = {
        Authorization = "Bearer ${config.sops.placeholder.CONTEXT7_API_KEY}";
      };
    };
    #firecrawl-mcp = {
    #  type = "http";
    #  url = "https://mcp.firecrawl.dev/${config.sops.placeholder.FIRECRAWL_API_KEY}/v2/mcp";
    #};
    github = {
      type = "http";
      url = "https://api.githubcopilot.com/mcp/";
      headers = {
        Authorization = "Bearer ${config.sops.placeholder.GITHUB_TOKEN}";
      };
    };
    jina-mcp-server = {
      type = "http";
      url = "https://mcp.jina.ai/v1?exclude_tools=deduplicate_strings,expand_query,parallel_search_arxiv,parallel_search_ssrn,parallel_search_web,show_api_key,search_arxiv,search_jina_blog,search_ssrn,search_web";
      headers = {
        Authorization = "Bearer ${config.sops.placeholder.JINA_API_KEY}";
      };
    };
    #mcp-google-cse = {
    #  type = "stdio";
    #  command = "${pkgs.uv}/bin/uvx";
    #  args = [ "mcp-google-cse" ];
    #  env = {
    #    API_KEY = config.sops.placeholder.GOOGLE_CSE_API_KEY;
    #    ENGINE_ID = config.sops.placeholder.GOOGLE_CSE_ENGINE_ID;
    #  };
    #};
  };

  # MCP servers for OpenCode - uses {env:VAR} syntax for secrets
  opencodeServers = {
    # Servers without secrets
    cloudflare = {
      enabled = false;
      type = "remote";
      url = "https://docs.mcp.cloudflare.com/mcp";
    };
    # Disabled because Exa is already included by default OpenCode
    #exa = {
    #  enabled = false;
    #  type = "remote";
    #  url = "https://mcp.exa.ai/mcp";
    #};
    nixos = {
      enabled = false;
      type = "local";
      command = [ "${pkgs.mcp-nixos}/bin/mcp-nixos" ];
    };
    svelte = {
      enabled = false;
      type = "local";
      command = [
        "${pkgs.nodejs_24}/bin/npx"
        "-y"
        "@sveltejs/mcp"
      ];
    };
    # Servers with secrets - using OpenCode's {env:VAR} syntax
    context7 = {
      type = "remote";
      url = "https://mcp.context7.com/mcp";
      headers = {
        CONTEXT7_API_KEY = "{env:CONTEXT7_API_KEY}";
      };
    };
    #firecrawl = {
    #  enabled = false;
    #  type = "remote";
    #  url = "https://mcp.firecrawl.dev/{env:FIRECRAWL_API_KEY}/v2/mcp";
    #};
    github = {
      enabled = false;
      type = "remote";
      url = "https://api.githubcopilot.com/mcp/";
      headers = {
        Authorization = "Bearer {env:GITHUB_TOKEN}";
      };
    };
    jina-mcp-server = {
      enabled = false;
      type = "remote";
      url = "https://mcp.jina.ai/v1?exclude_tools=deduplicate_strings,expand_query,parallel_search_arxiv,parallel_search_ssrn,parallel_search_web,show_api_key,search_arxiv,search_jina_blog,search_ssrn,search_web";
      headers = {
        Authorization = "Bearer {env:JINA_API_KEY}";
      };
    };
    #mcp-google-cse = {
    #  enabled = false;
    #  type = "local";
    #  command = [
    #    "${pkgs.uv}/bin/uvx"
    #    "mcp-google-cse"
    #  ];
    #  environment = {
    #    API_KEY = "{env:GOOGLE_CSE_API_KEY}";
    #    ENGINE_ID = "{env:GOOGLE_CSE_ENGINE_ID}";
    #  };
    #};
  };

  # MCP servers for Copilot CLI - only supports stdio/local with required tools/args arrays
  copilotMcpServers = {
    # Servers without secrets
    cloudflare = {
      type = "stdio";
      command = "${pkgs.nodejs_24}/bin/npx";
      args = [
        "-y"
        "mcp-remote"
        "https://docs.mcp.cloudflare.com/mcp"
      ];
      tools = [ "*" ];
    };
    exa = {
      type = "stdio";
      command = "${pkgs.nodejs_24}/bin/npx";
      args = [
        "-y"
        "mcp-remote"
        "https://mcp.exa.ai/mcp"
      ];
      tools = [ "*" ];
    };
    # GitHub is disabled because Copilot CLI already uses it by default
    #github = {
    #  type = "stdio";
    #  command = "${pkgs.nodejs_24}/bin/npx";
    #  args = [
    #    "-y"
    #    "mcp-remote"
    #    "https://api.githubcopilot.com/mcp/"
    #  ];
    #  tools = [ "*" ];
    #  env = {
    #    MCP_REMOTE_HEADERS = "Authorization: Bearer ${config.sops.placeholder.GITHUB_TOKEN}";
    #  };
    #};
    nixos = {
      type = "stdio";
      command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
      args = [ ];
      tools = [ "*" ];
    };
    svelte = {
      type = "stdio";
      command = "${pkgs.nodejs_24}/bin/npx";
      args = [
        "-y"
        "@sveltejs/mcp"
      ];
      tools = [ "*" ];
    };
    # Servers with secrets
    context7 = {
      type = "stdio";
      command = "${pkgs.nodejs_24}/bin/npx";
      args = [
        "-y"
        "@upstash/context7-mcp"
        "--api-key"
        config.sops.placeholder.CONTEXT7_API_KEY
      ];
      tools = [ "*" ];
    };
    #firecrawl-mcp = {
    #  type = "stdio";
    #  command = "${pkgs.nodejs_24}/bin/npx";
    #  args = [
    #    "-y"
    #    "firecrawl-mcp"
    #  ];
    #  tools = [
    #    "scrape"
    #    "batch_scrape"
    #    "map"
    #    "crawl"
    #    "extract"
    #  ];
    #  env = {
    #    FIRECRAWL_API_KEY = config.sops.placeholder.FIRECRAWL_API_KEY;
    #  };
    #};
    jina-mcp-server = {
      type = "stdio";
      command = "${pkgs.nodejs_24}/bin/npx";
      args = [
        "-y"
        "mcp-remote"
        "https://mcp.jina.ai/v1?exclude_tools=deduplicate_strings,expand_query,parallel_search_arxiv,parallel_search_ssrn,parallel_search_web,show_api_key,search_arxiv,search_jina_blog,search_ssrn,search_web"
        "--header"
        "Authorization: Bearer ${config.sops.placeholder.JINA_API_KEY}"
      ];
      tools = [ "*" ];
    };
    #mcp-google-cse = {
    #  type = "stdio";
    #  command = "${pkgs.uv}/bin/uvx";
    #  args = [ "mcp-google-cse" ];
    #  tools = [ "*" ];
    #  env = {
    #    API_KEY = config.sops.placeholder.GOOGLE_CSE_API_KEY;
    #    ENGINE_ID = config.sops.placeholder.GOOGLE_CSE_ENGINE_ID;
    #  };
    #};
  };
in
lib.mkIf (lib.elem username installFor) {
  programs = {
    fish = {
      shellInit = ''
        # Export MCP secrets from sops
        set -gx CONTEXT7_API_KEY (cat ${config.sops.secrets.CONTEXT7_API_KEY.path} 2>/dev/null; or echo "")
        set -gx FIRECRAWL_API_KEY (cat ${config.sops.secrets.FIRECRAWL_API_KEY.path} 2>/dev/null; or echo "")
        set -gx GOOGLE_CSE_API_KEY (cat ${config.sops.secrets.GOOGLE_CSE_API_KEY.path} 2>/dev/null; or echo "")
        set -gx GOOGLE_CSE_ENGINE_ID (cat ${config.sops.secrets.GOOGLE_CSE_ENGINE_ID.path} 2>/dev/null; or echo "")
        set -gx JINA_API_KEY (cat ${config.sops.secrets.JINA_API_KEY.path} 2>/dev/null; or echo "")
      '';
    };
    bash = {
      initExtra = ''
        # Export MCP secrets from sops
        export CONTEXT7_API_KEY=$(cat ${config.sops.secrets.CONTEXT7_API_KEY.path} 2>/dev/null || echo "")
        export FIRECRAWL_API_KEY=$(cat ${config.sops.secrets.FIRECRAWL_API_KEY.path} 2>/dev/null || echo "")
        export GOOGLE_CSE_API_KEY=$(cat ${config.sops.secrets.GOOGLE_CSE_API_KEY.path} 2>/dev/null || echo "")
        export GOOGLE_CSE_ENGINE_ID=$(cat ${config.sops.secrets.GOOGLE_CSE_ENGINE_ID.path} 2>/dev/null || echo "")
        export JINA_API_KEY=$(cat ${config.sops.secrets.JINA_API_KEY.path} 2>/dev/null || echo "")
      '';
    };
    opencode = lib.mkIf config.programs.opencode.enable {
      enableMcpIntegration = true;
      settings = {
        mcp = opencodeServers;
      };
    };
    vscode = lib.mkIf config.programs.vscode.enable {
      profiles.default = {
        userSettings = {
          "chat.mcp.assisted.nuget.enabled" = false;
          "chat.mcp.autostart" = "newAndOutdated";
          "chat.mcp.gallery.enabled" = true;
        };
      };
    };
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      extensions = [
        "mcp-server-context7"
        #"mcp-server-firecrawl"
        "svelte-mcp"
      ];
      userSettings = {
        context_servers = {
          cloudflare = {
            command = "${pkgs.nodejs_24}/bin/npx";
            args = [
              "-y"
              "mcp-remote"
              "https://docs.mcp.cloudflare.com/mcp"
            ];
          };
          exa = {
            command = "${pkgs.nodejs_24}/bin/npx";
            args = [
              "-y"
              "mcp-remote"
              "https://mcp.exa.ai/mcp"
            ];
          };
          nixos = {
            command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
            args = [ ];
          };
          jina = {
            command = "${pkgs.nodejs_24}/bin/npx";
            args = [
              "-y"
              "mcp-remote"
              "https://mcp.jina.ai/v1?exclude_tools=deduplicate_strings,expand_query,parallel_search_arxiv,parallel_search_ssrn,parallel_search_web,show_api_key,search_arxiv,search_jina_blog,search_ssrn,search_web"
            ];
          };
        };
      };
    };
  };
  sops = {
    secrets = {
      CONTEXT7_API_KEY = {
        sopsFile = mcpSopsFile;
      };
      FIRECRAWL_API_KEY = {
        sopsFile = mcpSopsFile;
      };
      GITHUB_TOKEN = {
        sopsFile = mcpSopsFile;
      };
      GOOGLE_CSE_API_KEY = {
        sopsFile = mcpSopsFile;
      };
      GOOGLE_CSE_ENGINE_ID = {
        sopsFile = mcpSopsFile;
      };
      JINA_API_KEY = {
        sopsFile = mcpSopsFile;
      };
    };
    # MCP servers - used by Claude Code
    templates."claude-mcp-config.json" = lib.mkIf config.programs.claude-code.enable {
      content = builtins.toJSON { inherit mcpServers; };
      path = "${config.home.homeDirectory}/.config/claude/mcp.json";
    };

    # MCP servers - used by other agents
    templates."mcp-config.json" = {
      content = builtins.toJSON { inherit mcpServers; };
      path = "${config.xdg.configHome}/mcp/mcp.json";
    };

    # MCP servers - used by VSCode which expects "servers" key not "mcpServers"
    templates."vscode-mcp-config.json" = lib.mkIf config.programs.vscode.enable {
      content = builtins.toJSON { servers = mcpServers; };
      path = "${vscodeUserDir}/mcp.json";
    };

    # MCP servers - used by GitHub Copilot CLI
    # NOTE: Copilot CLI uses ~/.config/.copilot/ (hidden folder inside .config)
    templates."copilot-cli-mcp-config.json" = {
      content = builtins.toJSON { mcpServers = copilotMcpServers; };
      path = "${config.xdg.configHome}/.copilot/mcp-config.json";
    };
  };
}
