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
  isWorkHost = lib.elem "workspace" (host.tags or [ ]);
in
rec {
  # Canonical MCP server definitions.
  # Phase 1 of the MCP refactor: this attrset is the single source of truth
  # for every MCP server and its per-consumer state. Renderers added in later
  # tasks transform these entries into the formats Claude Code, Codex,
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
  #                { clientId = "..."; callbackPort = <int>;
  #                  redirectUri = "..."; }. Renderers map this to each
  #                supported client's native schema.
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
  #                  zed.mode           "context_server" | "extension"
  #                  zed.id             extension id when mode = "extension"
  servers = {
    claude = {
      transport = "stdio";
      command = lib.getExe pkgs.claude-code;
      args = [
        "--strict-mcp-config"
        "mcp"
        "serve"
      ];
      startupTimeoutSec = 10;
      consumers = {
        # Claude's native MCP exposes an agent-calling-agent surface. Keep it
        # available only to Codex and avoid recursive Claude MCP exposure.
        claudeCode.enabled = false;
        codex = {
          enabled = true;
          defaultToolsApprovalMode = "prompt";
        };
        opencode.enabled = false;
        pi = {
          enabled = false;
          omit = true;
        };
        zed.enabled = false;
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

    linear = {
      # Official hosted Linear MCP server over Streamable HTTP with API-key
      # bearer authentication.
      transport = "http";
      url = "https://mcp.linear.app/mcp";
      auth = {
        kind = "bearer";
        envVar = "LINEAR_API_KEY";
      };
      consumers = {
        # Linear exposes issue/project/comment reads and mutations. Make Codex
        # ask before tool calls rather than inheriting the unattended default.
        codex.defaultToolsApprovalMode = "prompt";
      };
    };
  }
  // lib.optionalAttrs isWorkHost {
    slack = {
      # Official Slack-hosted MCP server over Streamable HTTP with OAuth.
      # Slack has no OAuth dynamic client registration, so the pre-registered
      # public client id and callback port from Slack's Claude connection guide
      # are supplied inline. Claude Code, Codex, OpenCode, and Pi each complete
      # the browser OAuth flow and store the resulting credentials locally.
      transport = "http";
      url = "https://mcp.slack.com/mcp";
      oauth = {
        clientId = "1601185624273.8899143856786";
        callbackPort = 3118;
        redirectUri = "http://localhost:3118/callback";
      };
      consumers = {
        zed.enabled = false;
      };
    };
  };

  # ---------------------------------------------------------------------------
  # Renderers
  # ---------------------------------------------------------------------------
  # Each renderer is a pure function of the canonical `servers` attrset above
  # and produces the format its target consumer expects. Consumers
  # (`claude-code`, `codex`, `mcp/default.nix` for OpenCode and Zed) read
  # these renderer outputs directly.
  #
  # Filter rules (shared except where noted):
  #   * Skip servers with global `enabled = false`.
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
            oauth = {
              inherit (s.oauth) clientId callbackPort;
            };
          }
        else
          {
            type = "stdio";
            inherit (s) command;
          }
          // lib.optionalAttrs ((s.args or [ ]) != [ ]) { inherit (s) args; };
    in
    lib.mapAttrs render (lib.filterAttrs keep servers);

  # codexServers: Codex's `config.toml` `[mcp_servers.<name>]` tables.
  # Codex's `RawMcpServerConfig` enforces `deny_unknown_fields`, so the
  # renderer must never emit fields outside its accepted set. The fields
  # we use here are: `url`, `bearer_token_env_var`, `command`, `args`,
  # `enabled`, `default_tools_approval_mode`, `startup_timeout_sec`, and
  # `oauth.client_id` - all defined on `RawMcpServerConfig`.
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
          // lib.optionalAttrs (s.oauth or null != null) {
            oauth.client_id = s.oauth.clientId;
          }
          // lib.optionalAttrs (s ? startupTimeoutSec) {
            startup_timeout_sec = s.startupTimeoutSec;
          }
        else
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
          // lib.optionalAttrs (s.oauth or null != null) {
            oauth = {
              clientId = s.oauth.clientId;
              inherit (s.oauth) redirectUri;
            };
          }
        else
          {
            type = "local";
            inherit enabled;
            # Canonical schema stores `command` as a string and `args` as a
            # list; OpenCode wants them concatenated into a single argv list.
            command = [ s.command ] ++ (s.args or [ ]);
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
          // lib.optionalAttrs (s.oauth or null != null) {
            oauth = {
              clientId = s.oauth.clientId;
              inherit (s.oauth) redirectUri;
            };
          }
        else
          {
            type = "stdio";
            inherit (s) command;
            args = s.args or [ ];
          }
          // common;
    in
    lib.mapAttrs render (lib.filterAttrs keep servers);

  codexOAuthCallbackPort = if isWorkHost then servers.slack.oauth.callbackPort else null;
  codexOAuthCallbackUrl = if isWorkHost then servers.slack.oauth.redirectUri else null;

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
            ]
            ++ lib.optionals (s.auth or null != null && s.auth.kind == "bearer") [
              "--header"
              ("Authorization: Bearer " + "$" + "{${s.auth.envVar}}")
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
            true
          else
            false
        );
      keptServers = lib.filterAttrs (
        _: s: lib.any (consumer: keptByConsumer consumer s) (lib.unique consumers)
      ) servers;
      authSecrets = lib.mapAttrsToList (
        _: s: if (s.auth or null) != null && s.auth.kind or null == "bearer" then [ s.auth.envVar ] else [ ]
      ) keptServers;
    in
    lib.sort lib.lessThan (lib.unique (lib.flatten authSecrets));

  # Full legacy set for callers that do not have an enabled-client context.
  requiredSecrets = requiredSecretsForConsumers [
    "claudeCode"
    "codex"
    "opencode"
    "pi"
    "zed"
  ];
}
