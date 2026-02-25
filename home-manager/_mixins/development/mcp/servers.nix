# Shared MCP server definitions
# Used by Claude Code, VSCode, Copilot CLI, OpenCode, Zed, and other tools
{
  config,
  pkgs,
  ...
}:
{
  # MCP servers for Claude Code, VSCode, and generic MCP clients
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
    jina = {
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
    exa = {
      type = "remote";
      url = "https://mcp.exa.ai/mcp";
    };
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
    jina = {
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
  # MCP servers for oterm - uses stdio (command/args) and HTTP (url with optional auth)
  otermMcpServers = {
    # Stdio servers
    nixos = {
      command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
      args = [ ];
    };
    # HTTP servers without auth
    cloudflare = {
      url = "https://docs.mcp.cloudflare.com/mcp";
    };
    exa = {
      url = "https://mcp.exa.ai/mcp";
    };
    svelte = {
      url = "https://mcp.svelte.dev/mcp";
    };
    # HTTP servers with bearer auth
    context7 = {
      url = "https://mcp.context7.com/mcp";
      auth = {
        type = "bearer";
        token = config.sops.placeholder.CONTEXT7_API_KEY;
      };
    };
    github = {
      url = "https://api.githubcopilot.com/mcp/";
      auth = {
        type = "bearer";
        token = config.sops.placeholder.GITHUB_TOKEN;
      };
    };
    jina = {
      url = "https://mcp.jina.ai/v1?exclude_tools=deduplicate_strings,expand_query,parallel_search_arxiv,parallel_search_ssrn,parallel_search_web,show_api_key,search_arxiv,search_jina_blog,search_ssrn,search_web";
      auth = {
        type = "bearer";
        token = config.sops.placeholder.JINA_API_KEY;
      };
    };
  };

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
    jina = {
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
}
