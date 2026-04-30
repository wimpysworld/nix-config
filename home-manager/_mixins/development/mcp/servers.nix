# Shared MCP server definitions
# Used by Claude Code, OpenCode, Zed, Codex, and other MCP clients.
{
  config,
  pkgs,
  ...
}:
{
  # MCP servers for Claude Code and generic MCP clients.
  # Uses config.sops.placeholder to inject secrets at activation time.
  mcpServers = {
    # Servers without secrets
    cloudflare = {
      type = "http";
      url = "https://docs.mcp.cloudflare.com/mcp";
    };
    exa = {
      type = "http";
      url = "https://mcp.exa.ai/mcp?tools=web_search_exa,web_fetch_exa,web_search_advanced_exa";
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
    # jina = {
    #   type = "http";
    #   url = "https://mcp.jina.ai/v1?exclude_tools=deduplicate_strings,expand_query,parallel_search_arxiv,parallel_search_ssrn,parallel_search_web,show_api_key,search_arxiv,search_jina_blog,search_ssrn,search_web";
    #   headers = {
    #     Authorization = "Bearer ${config.sops.placeholder.JINA_API_KEY}";
    #   };
    # };
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

  # Canonical MCP server definitions.
  # Phase 1 of the MCP refactor: this attrset is the single source of truth
  # for every MCP server and its per-consumer state. Renderers added in later
  # tasks transform these entries into the shapes Claude Code, Codex,
  # OpenCode, and Zed expect. While renderers are absent, the legacy
  # `mcpServers` and `opencodeServers` attrsets above remain the live data
  # and must stay byte-identical to their pre-refactor form.
  #
  # Schema reference (per entry):
  #   enabled    - global on/off, defaults to true when omitted
  #   transport  - "http" or "stdio"
  #   url        - http transport only
  #   command    - stdio transport only, string form
  #   args       - optional, stdio only, defaults to []
  #   auth       - optional, currently only { kind = "bearer"; envVar = "..."; }
  #   env        - optional, stdio env passthrough; values are env var names
  #   consumers  - optional per-consumer overrides:
  #                  claudeCode.enabled (default true)
  #                  codex.enabled      (default true)
  #                  opencode.enabled   (default true)
  #                  zed.mode           "context_server" | "extension" | "skip"
  #                  zed.id             extension id when mode = "extension"
  servers = {
    cloudflare = {
      transport = "http";
      url = "https://docs.mcp.cloudflare.com/mcp";
      consumers = {
        # OpenCode keeps cloudflare visible but disabled so the TUI can toggle
        # it at runtime; matches today's `opencodeServers.cloudflare.enabled = false`.
        opencode.enabled = false;
        zed.mode = "context_server";
      };
    };

    context7 = {
      transport = "http";
      url = "https://mcp.context7.com/mcp";
      auth = {
        kind = "bearer";
        envVar = "CONTEXT7_API_KEY";
      };
      consumers = {
        # Zed installs context7 via its extension marketplace rather than as a
        # context server; the extension id is the Zed registry slug.
        zed = {
          mode = "extension";
          id = "mcp-server-context7";
        };
      };
    };

    exa = {
      transport = "http";
      url = "https://mcp.exa.ai/mcp?tools=web_search_exa,web_fetch_exa,web_search_advanced_exa";
      consumers = {
        zed.mode = "context_server";
      };
    };

    nixos = {
      transport = "stdio";
      command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
      args = [ ];
      consumers = {
        zed.mode = "context_server";
      };
    };

    svelte = {
      transport = "http";
      url = "https://mcp.svelte.dev/mcp";
      consumers = {
        # Mirrors today's `opencodeServers.svelte.enabled = false`.
        opencode.enabled = false;
        zed = {
          mode = "extension";
          id = "svelte-mcp";
        };
      };
    };

    # Disabled servers retained as real entries with `enabled = false`. This
    # gives a single off-switch (flip `enabled = true` to re-enable) and keeps
    # them visible to the renderers and `requiredSecrets` derivation. The
    # commented blocks in `mcpServers` and `opencodeServers` above are the
    # legacy form and remain untouched while phase 1 is in flight.

    # Firecrawl embeds the API key in the URL path rather than supplying it
    # via a header. This does not fit `auth.kind = "bearer"`, so the URL
    # carries a literal `config.sops.placeholder` interpolation and the entry
    # has no `auth` attribute. Re-enabling firecrawl will require renderer
    # logic to translate the interpolated URL into OpenCode's `{env:VAR}`
    # syntax (see today's commented block in `opencodeServers`).
    firecrawl = {
      enabled = false;
      transport = "http";
      url = "https://mcp.firecrawl.dev/${config.sops.placeholder.FIRECRAWL_API_KEY}/v2/mcp";
      consumers = {
        zed.mode = "skip";
      };
    };

    jina = {
      enabled = false;
      transport = "http";
      url = "https://mcp.jina.ai/v1?exclude_tools=deduplicate_strings,expand_query,parallel_search_arxiv,parallel_search_ssrn,parallel_search_web,show_api_key,search_arxiv,search_jina_blog,search_ssrn,search_web";
      auth = {
        kind = "bearer";
        envVar = "JINA_API_KEY";
      };
      consumers = {
        zed.mode = "skip";
      };
    };

    # `env` attribute names are the env vars the spawned process sees; values
    # name the sops secret to inject. The `requiredSecrets` derivation in
    # task 1.6 will read these values.
    mcpGoogleCse = {
      enabled = false;
      transport = "stdio";
      command = "${pkgs.uv}/bin/uvx";
      args = [ "mcp-google-cse" ];
      env = {
        API_KEY = "GOOGLE_CSE_API_KEY";
        ENGINE_ID = "GOOGLE_CSE_ENGINE_ID";
      };
      consumers = {
        zed.mode = "skip";
      };
    };
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
      url = "https://mcp.exa.ai/mcp?tools=web_search_exa,web_fetch_exa,web_search_advanced_exa";
    };
    nixos = {
      enabled = true;
      type = "local";
      command = [ "${pkgs.mcp-nixos}/bin/mcp-nixos" ];
    };
    svelte = {
      enabled = false;
      type = "local";
      command = [
        "${pkgs.nodejs}/bin/npx"
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
    # jina = {
    #   type = "remote";
    #   url = "https://mcp.jina.ai/v1?exclude_tools=deduplicate_strings,expand_query,parallel_search_arxiv,parallel_search_ssrn,parallel_search_web,show_api_key,search_arxiv,search_jina_blog,search_ssrn,search_web";
    #   headers = {
    #     Authorization = "Bearer {env:JINA_API_KEY}";
    #   };
    # };
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

}
