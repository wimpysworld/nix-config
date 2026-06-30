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
  inherit (config.noughty) host;
  isBane = host.name == "bane";
  chromiumEnabled = config.programs.chromium.enable || (host.is.linux && host.is.workstation);
  firefoxEnabled = config.programs.firefox.enable || (host.is.linux && host.is.workstation);
  browserAutomationEnabled = chromiumEnabled && firefoxEnabled;
  mcpNixosNoUpdateCheck = pkgs.writeShellApplication {
    name = "mcp-nixos-no-update-check";
    text = ''
      export FASTMCP_CHECK_FOR_UPDATES=off
      exec ${pkgs.mcp-nixos}/bin/mcp-nixos "$@"
    '';
  };
  playwrightMcpWithNixBrowser = pkgs.writeShellApplication {
    name = "playwright-mcp-with-nix-browser";
    text = ''
      has_proxy_server_arg=false
      proxy_server=""

      for arg in "$@"; do
        case "$arg" in
          --proxy-server|--proxy-server=*)
            has_proxy_server_arg=true
            ;;
        esac
      done

      if [ "$has_proxy_server_arg" = false ] && [ "''${NOUGHTY_AGENT_ISOLATION-}" = Fenced ]; then
        for candidate in "''${HTTPS_PROXY-}" "''${https_proxy-}" "''${HTTP_PROXY-}" "''${http_proxy-}"; do
          if [ -n "$candidate" ]; then
            proxy_server="$candidate"
            break
          fi
        done
      fi

      if [ -n "$proxy_server" ]; then
        exec ${pkgs.playwright-mcp}/bin/.playwright-mcp-wrapped "$@" "--proxy-server=$proxy_server"
      fi

      exec ${pkgs.playwright-mcp}/bin/.playwright-mcp-wrapped "$@"
    '';
  };
  playwrightChromiumHeadlessShell = pkgs.playwright-driver.components."chromium-headless-shell";
  playwrightChromiumExecutable =
    if pkgs.stdenv.hostPlatform.isLinux then
      "${playwrightChromiumHeadlessShell}/chrome-headless-shell-linux64/chrome-headless-shell"
    else
      throw "Playwright MCP Chromium executable is not configured for ${pkgs.stdenv.hostPlatform.system}";
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
  #   oauth      - optional, http transport only; pre-registered OAuth client
  #                for servers without dynamic client registration:
  #                { clientId = "..."; callbackPort = <int>; }. Emitted only
  #                into Claude Code's config; other consumers have no config
  #                field for a pre-set client id.
  #   env        - optional, stdio env passthrough; values are env var names
  #   startupTimeoutSec
  #              - optional, integer seconds; rendered into Codex's
  #                `startup_timeout_sec` to bound how long the leader waits for
  #                the server to come up. Used to bound the visible window of
  #                the upstream sub-agent MCP startup leak (openai/codex
  #                #18068, #16821, #19542) where sub-agent startup events
  #                surface in the leader TUI's status header.
  #   consumers  - optional per-consumer overrides:
  #                  claudeCode.enabled (default true) - Claude Code's JSON
  #                                     MCP schema has no disabled/server
  #                                     toggle field, so `false` omits the
  #                                     server from Claude's active config.
  #                  codex.enabled      (default true) - mirrors OpenCode:
  #                                     `false` keeps the `[mcp_servers.<name>]`
  #                                     table with `enabled = false` so
  #                                     `codex mcp list` still sees it but
  #                                     Codex skips initialising the server.
  #                  codex.defaultToolsApprovalMode
  #                                     "auto" | "prompt" | "approve"; defaults
  #                                     to "approve" to preserve unattended
  #                                     agent runs unless a server needs a
  #                                     narrower human-review posture.
  #                  opencode.enabled   (default true)
  #                  pi.enabled         (default true) - mirrors OpenCode:
  #                                     `false` keeps the server visible in
  #                                     Pi's MCP TUI with `enabled = false` so
  #                                     it can be toggled at runtime.
  #                  pi.omit            bool, default false - hard-omits the
  #                                     server from Pi when even a manual toggle
  #                                     would be unsafe or unwanted.
  #                  pi.directTools     bool | list of strings, default follows
  #                                     `consumers.opencode.enabled`: `true`
  #                                     promotes the server's tools into Pi's
  #                                     first-class tool list, `false` leaves
  #                                     the server proxy-only through Pi's
  #                                     single `mcp` tool, and a list promotes
  #                                     only the named original MCP tools.
  #                  zed.enabled        (default true) - mirrors OpenCode:
  #                                     `false` keeps the entry visible in
  #                                     Zed's agent panel with `enabled = false`
  #                                     so the user can toggle at runtime.
  #                  zed.mode           "context_server" | "extension" | "skip"
  #                  zed.id             extension id when mode = "extension"
  servers = {
    cloudflare = {
      transport = "http";
      url = "https://docs.mcp.cloudflare.com/mcp";
      consumers = {
        claudeCode.enabled = false;
        codex.enabled = false;
        opencode.enabled = false;
        pi.enabled = false;
        zed.mode = "context_server";
      };
    };

    codex = {
      transport = "stdio";
      command = lib.getExe config.programs.codex.package;
      args = [ "mcp-server" ];
      consumers = {
        # Native Codex MCP is an agent-calling-agent surface. Keep it
        # available only to Claude Code and avoid recursive Codex exposure.
        claudeCode.enabled = true;
        codex.enabled = false;
        opencode.enabled = false;
        pi = {
          enabled = false;
          omit = true;
        };
        zed.enabled = false;
      };
    };

    context7 = {
      transport = "http";
      url = "https://mcp.context7.com/mcp";
      auth = {
        kind = "bearer";
        envVar = "CONTEXT7_API_KEY";
      };
      # Cap startup wait so a slow context7 handshake does not leave the
      # leader's "Starting MCP servers" indicator stuck when sub-agents
      # spawn. See the schema note above and openai/codex #18068.
      startupTimeoutSec = 10;
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
      command = lib.getExe mcpNixosNoUpdateCheck;
      args = [ ];
      consumers = {
        claudeCode.enabled = false;
        codex.enabled = false;
        opencode.enabled = false;
        pi.enabled = false;
        zed.mode = "context_server";
      };
    };

  }
  // lib.optionalAttrs browserAutomationEnabled {
    playwright = {
      transport = "stdio";
      command = lib.getExe playwrightMcpWithNixBrowser;
      args = [
        "--executable-path"
        playwrightChromiumExecutable
        "--headless"
      ];
      consumers = {
        claudeCode.enabled = false;
        codex.enabled = false;
        opencode.enabled = false;
        pi.enabled = false;
        zed.mode = "context_server";
      };
    };
  }
  // lib.optionalAttrs isBane {
    linear = {
      # Official hosted Linear MCP server. It uses Streamable HTTP with OAuth
      # 2.1 dynamic client registration by default; Linear also supports
      # bearer API keys, but no Linear secret is currently declared here.
      transport = "http";
      url = "https://mcp.linear.app/mcp";
      consumers = {
        # Linear exposes issue/project/comment reads and mutations. Keep it
        # active only in the requested clients, and make Codex ask before tool
        # calls rather than inheriting the unattended default.
        codex.defaultToolsApprovalMode = "prompt";
        opencode.enabled = false;
        pi = {
          enabled = false;
          omit = true;
        };
        zed.enabled = false;
      };
    };

    rag = {
      transport = "http";
      url = "https://rag-mcp.enforce.dev/mcp";
    };

    slack = {
      # Official Slack-hosted MCP server over Streamable HTTP with OAuth.
      # Slack has no OAuth dynamic client registration, so the pre-registered
      # public client id and callback port from Anthropic's published Slack app
      # are supplied inline. Sign-in is a one-time interactive `/mcp` browser
      # flow per machine, which routes through Okta SSO; the token lands in the
      # OS keychain, not here. Only Claude Code consumes this, because its JSON
      # MCP schema accepts the `oauth` block. Codex, OpenCode, Pi, and Zed have
      # no config field for a pre-registered client id, so they stay disabled
      # to avoid emitting a broken OAuth server.
      transport = "http";
      url = "https://mcp.slack.com/mcp";
      oauth = {
        clientId = "1601185624273.8899143856786";
        callbackPort = 3118;
      };
      consumers = {
        codex.enabled = false;
        opencode.enabled = false;
        pi = {
          enabled = false;
          omit = true;
        };
        zed.enabled = false;
      };
    };
  }
  // {
    svelte = {
      transport = "http";
      url = "https://mcp.svelte.dev/mcp";
      consumers = {
        claudeCode.enabled = false;
        codex.enabled = false;
        opencode.enabled = false;
        pi.enabled = false;
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
  #   * For Claude Code, skip servers where `consumers.claudeCode.enabled`
  #     is explicitly false (default true).
  #   * Codex, OpenCode, and Zed share the emit-with-disabled pattern when a
  #     future server opts out for that consumer: per-consumer
  #     `enabled = false` keeps the server in the output with `enabled = false`
  #     so each tool's surface (codex mcp list, OpenCode TUI, Zed agent panel)
  #     can toggle it at runtime. See AC 8 of MCP-PROPOSAL.md.

  # claudeServers: Claude Code and any generic MCP client that follows the
  # original `mcpServers` schema.
  claudeServers =
    let
      keep = _: s: (s.enabled or true) && (s.consumers.claudeCode.enabled or true);
      render =
        _: s:
        if s.transport == "http" then
          {
            type = "http";
            inherit (s) url;
          }
          // lib.optionalAttrs (s.auth or null != null && s.auth.kind == "bearer") {
            headers = {
              Authorization = "Bearer ${config.sops.placeholder.${s.auth.envVar}}";
            };
          }
          // lib.optionalAttrs (s.oauth or null != null) {
            inherit (s) oauth;
          }
        else
          {
            type = "stdio";
            inherit (s) command;
          }
          // lib.optionalAttrs ((s.args or [ ]) != [ ]) { inherit (s) args; }
          // lib.optionalAttrs ((s.env or { }) != { }) {
            # Translate canonical `env.KEY = "SECRET_NAME"` into the
            # placeholder interpolation Claude Code reads at activation time.
            env = lib.mapAttrs (_: secretName: config.sops.placeholder.${secretName}) s.env;
          };
    in
    lib.mapAttrs render (lib.filterAttrs keep servers);

  # codexServers: Codex's `config.toml` `[mcp_servers.<name>]` tables.
  # Codex's `RawMcpServerConfig` enforces `deny_unknown_fields`, so the
  # renderer must never emit fields outside its accepted set. The fields
  # we use here are: `url`, `bearer_token_env_var`, `command`, `args`,
  # `env`, and `enabled` - all defined on `RawMcpServerConfig`.
  #
  # Per-consumer disable mirrors OpenCode and Zed: `consumers.codex.enabled
  # = false` keeps the entry in the rendered `[mcp_servers.<name>]` table
  # with `enabled = false` so `codex mcp list` still shows the server but
  # Codex skips initialising it. Globally-disabled servers
  # (`enabled = false` at the top level) are excluded entirely.
  codexServers =
    let
      keep = _: s: s.enabled or true;
      # Auto-approve MCP tools by default for unattended agent runs. Individual
      # servers can tighten this when their tool surface can mutate external
      # state. Codex's `RawMcpServerConfig` accepts `auto`, `prompt`, and
      # `approve`.
      common = s: {
        default_tools_approval_mode = s.consumers.codex.defaultToolsApprovalMode or "approve";
      };
      render =
        _: s:
        let
          enabled = s.consumers.codex.enabled or true;
        in
        if s.transport == "http" then
          {
            inherit enabled;
            inherit (s) url;
          }
          // common s
          // lib.optionalAttrs (s.auth or null != null && s.auth.kind == "bearer") {
            bearer_token_env_var = s.auth.envVar;
          }
          // lib.optionalAttrs (s ? startupTimeoutSec) {
            startup_timeout_sec = s.startupTimeoutSec;
          }
        else
          # Codex's config.toml env table holds static literals with no secret
          # resolution, so the canonical `env` (values are sops secret names) is
          # NOT emitted here. Codex's MCP child inherits the real token from the
          # sops-exported shell environment (see mcp/default.nix shellInit), the
          # same path the user's interactive shell uses.
          {
            inherit enabled;
            inherit (s) command;
            args = s.args or [ ];
          }
          // common s
          // lib.optionalAttrs (s ? startupTimeoutSec) {
            startup_timeout_sec = s.startupTimeoutSec;
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
            inherit (s) url;
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

  # piServers: Pi adapter server entries for `~/.pi/agent/mcp.json`.
  # `pi-mcp-adapter` supports per-server `enabled` flags, so
  # `consumers.pi.enabled = false` keeps the server visible but disabled by
  # default for runtime toggling in Pi's MCP TUI. `consumers.pi.omit = true`
  # hard-excludes servers that should not be toggleable in Pi.
  #
  # The adapter shallow-merges MCP config files by server name. Entries here
  # therefore include the complete server definition, not only Pi-specific
  # overrides, otherwise adding `directTools` would replace the shared entry
  # and drop command, args, URL, or auth data.
  #
  # Pi's direct-tool preference follows OpenCode's enabled-by-default state:
  # OpenCode-enabled servers get `directTools = true`, while OpenCode-disabled
  # servers remain present but proxy-only with `directTools = false`. A future
  # `consumers.pi.directTools = [ ... ]` override can promote only selected
  # original MCP tool names where Pi needs a narrower direct surface.
  piServers =
    let
      keep = _: s: (s.enabled or true) && (!(s.consumers.pi.omit or false));
      enabledFor = s: s.consumers.pi.enabled or true;
      directToolsFor = s: s.consumers.pi.directTools or (s.consumers.opencode.enabled or true);
      render =
        _: s:
        let
          enabled = enabledFor s;
          common = {
            inherit enabled;
            directTools = if enabled then directToolsFor s else false;
          };
        in
        if s.transport == "http" then
          {
            type = "http";
            inherit (s) url;
          }
          // common
          // lib.optionalAttrs (s.auth or null != null && s.auth.kind == "bearer") {
            headers = {
              Authorization = "Bearer ${config.sops.placeholder.${s.auth.envVar}}";
            };
          }
        else
          {
            type = "stdio";
            inherit (s) command;
            args = s.args or [ ];
          }
          // common
          // lib.optionalAttrs ((s.env or { }) != { }) {
            env = lib.mapAttrs (_: secretName: config.sops.placeholder.${secretName}) s.env;
          };
    in
    lib.mapAttrs render (lib.filterAttrs keep servers);

  # zedContextServers: entries Zed launches as local context servers, either
  # by spawning the canonical stdio command directly or by wrapping an HTTP
  # endpoint with `npx mcp-remote <url>` (Zed's standard pattern for remote
  # MCP servers). Servers tagged `zed.mode = "extension"` install via Zed's
  # extension marketplace instead and appear in `zedExtensions` below.
  #
  # Per-consumer disable mirrors OpenCode: `consumers.zed.enabled = false`
  # keeps the entry in the output with `enabled = false` so Zed's agent
  # panel shows it as a toggleable disabled server. Zed's
  # `ContextServerSettingsContent` enum (Stdio / Http / Extension) accepts
  # `enabled` on every variant, defaulting to true.
  zedContextServers =
    let
      keep =
        _: s: (s.enabled or true) && ((s.consumers.zed.mode or "context_server") == "context_server");
      render =
        _: s:
        let
          enabled = s.consumers.zed.enabled or true;
        in
        if s.transport == "http" then
          {
            inherit enabled;
            command = "${pkgs.nodejs}/bin/npx";
            args = [
              "-y"
              "mcp-remote"
              s.url
            ];
          }
        else
          {
            inherit enabled;
            inherit (s) command;
            args = s.args or [ ];
          };
    in
    lib.mapAttrs render (lib.filterAttrs keep servers);

  # zedExtensions: alphabetically sorted list of Zed extension ids for
  # servers tagged `zed.mode = "extension"`. Zed installs these from its
  # extension marketplace; they do not need a context_servers entry when
  # enabled.
  #
  # Disabling an extension-mode server (`consumers.zed.enabled = false`)
  # keeps the extension installed but pairs it with a disabled stub entry
  # in `zedExtensionDisables` so Zed's agent panel can toggle it back on.
  zedExtensions =
    let
      keep = _: s: (s.enabled or true) && ((s.consumers.zed.mode or null) == "extension");
      ids = lib.mapAttrsToList (_: s: s.consumers.zed.id) (lib.filterAttrs keep servers);
    in
    lib.sort lib.lessThan ids;

  # zedExtensionDisables: stub `context_servers` entries for extension-mode
  # servers whose `consumers.zed.enabled` is false. Zed identifies the
  # `Extension` variant by the presence of a `settings` field; an empty
  # object means "no overrides" while `enabled = false` flips the toggle off.
  # Merged into `userSettings.context_servers` alongside `zedContextServers`.
  zedExtensionDisables =
    let
      keep =
        _: s:
        (s.enabled or true)
        && ((s.consumers.zed.mode or null) == "extension")
        && (!(s.consumers.zed.enabled or true));
      disabled = lib.filterAttrs keep servers;
    in
    lib.listToAttrs (
      lib.mapAttrsToList (_: s: {
        name = s.consumers.zed.id;
        value = {
          enabled = false;
          settings = { };
        };
      }) disabled
    );

  # requiredSecretsForConsumers: sorted list of distinct env var names needed
  # by enabled consumers. Per-consumer disabled entries still count for clients
  # that render them as visible but disabled. Hard-omitted consumers do not.
  requiredSecretsForConsumers =
    consumers:
    let
      keptByConsumer =
        consumer: s:
        (s.enabled or true)
        && (
          if consumer == "claudeCode" then
            s.consumers.claudeCode.enabled or true
          else if consumer == "codex" then
            true
          else if consumer == "opencode" then
            true
          else if consumer == "pi" then
            !(s.consumers.pi.omit or false)
          else if consumer == "zed" then
            (s.consumers.zed.mode or "context_server") != "skip"
          else
            false
        );
      keptServers = lib.filterAttrs (
        _: s: lib.any (consumer: keptByConsumer consumer s) (lib.unique consumers)
      ) servers;
      authSecrets = lib.mapAttrsToList (
        _: s: if (s.auth or null) != null && s.auth.kind or null == "bearer" then [ s.auth.envVar ] else [ ]
      ) keptServers;
      envSecrets = lib.mapAttrsToList (_: s: lib.attrValues (s.env or { })) keptServers;
    in
    lib.sort lib.lessThan (lib.unique (lib.flatten (authSecrets ++ envSecrets)));

  # Full legacy set for callers that do not have an enabled-client context.
  requiredSecrets = requiredSecretsForConsumers [
    "claudeCode"
    "codex"
    "opencode"
    "pi"
    "zed"
  ];
}
