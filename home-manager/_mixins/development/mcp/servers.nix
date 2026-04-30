# Shared MCP server definitions
# Used by Claude Code, OpenCode, Zed, Codex, and other MCP clients.
{
  config,
  pkgs,
  ...
}:
let
  # `lib` is sourced from `pkgs` so callers (codex/default.nix and
  # claude-code/default.nix) do not need to pass it explicitly. Both
  # currently invoke this file with `{ inherit config pkgs; }`.
  inherit (pkgs) lib;
in
rec {
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

  # ---------------------------------------------------------------------------
  # Renderers
  # ---------------------------------------------------------------------------
  # Each renderer is a pure function of the canonical `servers` attrset above
  # and produces the shape its target consumer expects. Consumers
  # (`claude-code`, `codex`, `mcp/default.nix` for OpenCode and Zed) read
  # these renderer outputs directly.
  #
  # Filter rules (shared except where noted):
  #   * Skip servers with global `enabled = false` (firecrawl, jina,
  #     mcpGoogleCse today).
  #   * For Claude Code, Codex, and Zed, also skip servers where
  #     `consumers.<tool>.enabled` is explicitly false (default true).
  #   * OpenCode is the exception: per-consumer `enabled = false` keeps the
  #     server in the output with `enabled = false` so the TUI can toggle it
  #     at runtime. See AC 8 of MCP-PROPOSAL.md.

  # claudeServers: Claude Code and any generic MCP client that follows the
  # original `mcpServers` schema. Output is byte-equivalent to today's
  # `mcpServers` attribute for the five active servers.
  claudeServers =
    let
      keep = _: s: (s.enabled or true) && (s.consumers.claudeCode.enabled or true);
      render =
        _: s:
        if s.transport == "http" then
          {
            type = "http";
            url = s.url;
          }
          // lib.optionalAttrs (s.auth or null != null && s.auth.kind == "bearer") {
            headers = {
              Authorization = "Bearer ${config.sops.placeholder.${s.auth.envVar}}";
            };
          }
        else
          {
            type = "stdio";
            command = s.command;
          }
          // lib.optionalAttrs ((s.args or [ ]) != [ ]) { args = s.args; }
          // lib.optionalAttrs ((s.env or { }) != { }) {
            # Translate canonical `env.KEY = "SECRET_NAME"` into the
            # placeholder interpolation Claude Code reads at activation time.
            env = lib.mapAttrs (_: secretName: config.sops.placeholder.${secretName}) s.env;
          };
    in
    lib.mapAttrs render (lib.filterAttrs keep servers);

  # codexServers: Codex's `config.toml` `[mcp_servers.<name>]` tables.
  # Codex enforces `additionalProperties = false`, so the renderer must
  # never emit a `type` field or any other key beyond the four below:
  # `url`, `bearer_token_env_var`, `command`, `args`, plus an optional
  # `env` for stdio servers with a static environment.
  codexServers =
    let
      keep = _: s: (s.enabled or true) && (s.consumers.codex.enabled or true);
      render =
        _: s:
        if s.transport == "http" then
          {
            url = s.url;
          }
          // lib.optionalAttrs (s.auth or null != null && s.auth.kind == "bearer") {
            bearer_token_env_var = s.auth.envVar;
          }
        else
          {
            command = s.command;
            args = s.args or [ ];
          }
          // lib.optionalAttrs ((s.env or { }) != { }) {
            # Codex consumes the env table as static literals; the canonical
            # value is the sops secret name, which Codex resolves itself at
            # process-launch time via `bearer_token_env_var`-style hooks.
            # No active server uses this today; shape preserved for parity.
            env = s.env;
          };
    in
    lib.mapAttrs render (lib.filterAttrs keep servers);

  # opencodeServers: OpenCode's `mcp` settings block. Bearer-auth servers
  # emit `headers.Authorization = "Bearer {env:<envVar>}"` per AC 7 of
  # MCP-PROPOSAL.md.
  #
  # Per-consumer disable does NOT omit the entry: AC 8 requires the server
  # to remain visible in the OpenCode TUI with `enabled = false` so it can
  # be toggled at runtime. The renderer therefore filters only on the
  # global `enabled` flag and reflects `consumers.opencode.enabled` into
  # the emitted `enabled` field.
  opencodeServers =
    let
      keep = _: s: s.enabled or true;
      render =
        _: s:
        let
          enabled = s.consumers.opencode.enabled or true;
        in
        if s.transport == "http" then
          {
            type = "remote";
            inherit enabled;
            url = s.url;
          }
          // lib.optionalAttrs (s.auth or null != null && s.auth.kind == "bearer") {
            headers = {
              Authorization = "Bearer {env:${s.auth.envVar}}";
            };
          }
        else
          {
            type = "local";
            inherit enabled;
            # Canonical schema stores `command` as a string and `args` as a
            # list; OpenCode wants them concatenated into a single argv list.
            command = [ s.command ] ++ (s.args or [ ]);
          }
          // lib.optionalAttrs ((s.env or { }) != { }) {
            environment = lib.mapAttrs (_: secretName: "{env:${secretName}}") s.env;
          };
    in
    lib.mapAttrs render (lib.filterAttrs keep servers);

  # zedContextServers: entries Zed launches as local context servers, either
  # by spawning the canonical stdio command directly or by wrapping an HTTP
  # endpoint with `npx mcp-remote <url>` (Zed's standard pattern for remote
  # MCP servers). Servers tagged `zed.mode = "extension"` install via Zed's
  # extension marketplace instead and appear in `zedExtensions` below.
  zedContextServers =
    let
      keep =
        _: s: (s.enabled or true) && ((s.consumers.zed.mode or "context_server") == "context_server");
      render =
        _: s:
        if s.transport == "http" then
          {
            command = "${pkgs.nodejs}/bin/npx";
            args = [
              "-y"
              "mcp-remote"
              s.url
            ];
          }
        else
          {
            command = s.command;
            args = s.args or [ ];
          };
    in
    lib.mapAttrs render (lib.filterAttrs keep servers);

  # zedExtensions: alphabetically sorted list of Zed extension ids for
  # servers tagged `zed.mode = "extension"`. Zed installs these from its
  # extension marketplace; they do not need a context_servers entry.
  zedExtensions =
    let
      keep = _: s: (s.enabled or true) && ((s.consumers.zed.mode or null) == "extension");
      ids = lib.mapAttrsToList (_: s: s.consumers.zed.id) (lib.filterAttrs keep servers);
    in
    lib.sort lib.lessThan ids;

  # requiredSecrets: sorted list of distinct env var names referenced by any
  # enabled server's `auth.envVar` or `env` values. Task 3.1 will feed this
  # into `sops.secrets` so a server's secret declarations follow the canonical
  # entry rather than living in a separate hand-maintained list.
  #
  # Per-consumer `consumers.<tool>.enabled = false` does NOT gate inclusion;
  # only the global `enabled` flag does. A server consumed only by tools that
  # opt out still needs its secret available at activation, otherwise the
  # `config.sops.placeholder` interpolation in the renderer outputs would
  # fail to resolve. With current data this list resolves to
  # `["CONTEXT7_API_KEY"]`.
  requiredSecrets =
    let
      enabledServers = lib.filterAttrs (_: s: s.enabled or true) servers;
      authSecrets = lib.mapAttrsToList (
        _: s: if (s.auth or null) != null && s.auth.kind or null == "bearer" then [ s.auth.envVar ] else [ ]
      ) enabledServers;
      envSecrets = lib.mapAttrsToList (_: s: lib.attrValues (s.env or { })) enabledServers;
    in
    lib.sort lib.lessThan (lib.unique (lib.flatten (authSecrets ++ envSecrets)));
}
