# MCP Servers

Five unconditional MCP servers provide reference material and agent delegation. Slack is emitted only on hosts tagged `workspace`. Definitions live once in `servers.nix` and are distributed to each enabled Claude Code, OpenCode, Zed, Codex, and Pi Agent client via per-consumer renderers.

The Nix composition is the delivery mechanism, not the strategy. Most servers here are information retrieval tools: documentation search, web reading, and package lookup. The practical reason: a language model with a training cutoff hallucinates library APIs that changed after the cutoff. A model that fetches live documentation does not need to guess.

## Contents

- [Architecture](#architecture)
- [Canonical schema](#canonical-schema)
- [Servers](#servers)
- [Platform delivery](#platform-delivery)
- [Secrets](#secrets)
- [Adding a server](#adding-a-server)

---

## Architecture

`servers.nix` is the single source of truth. It exports:

| Attribute              | Purpose                                                                          |
| ---------------------- | -------------------------------------------------------------------------------- |
| `servers`              | Canonical attrset; one entry per MCP server                                      |
| `claudeServers`        | Renderer for Claude Code's `mcpServers` JSON template                            |
| `codexServers`         | Renderer for Codex's `[mcp_servers.*]` TOML tables                               |
| `opencodeServers`      | Renderer for OpenCode's `mcp` settings block                                     |
| `piServers`            | Renderer for Pi's `pi-mcp-adapter` server overrides with Pi-native `directTools` |
| `zedContextServers`    | Renderer for Zed's `context_servers` setting (stdio + HTTP)                      |
| `zedExtensions`        | Sorted list of Zed extension marketplace ids                                     |
| `zedExtensionDisables` | Stub `context_servers` entries that flip extension-mode servers off              |
| `requiredSecretsForConsumers` | Function returning env var names needed by the selected consumers         |
| `requiredSecrets`      | Full legacy secret set for callers without an enabled-client context             |

Each renderer is a pure function of the canonical `servers` attrset. Adding or modifying a server means editing one entry; the renderers and `requiredSecretsForConsumers` derivation pick up the change automatically.

---

## Canonical schema

Each entry in `servers` carries the following fields. Only `transport` is mandatory; everything else has sensible defaults or is conditional on transport.

| Field       | Type                  | Required | Notes                                                                                                     |
| ----------- | --------------------- | -------- | --------------------------------------------------------------------------------------------------------- |
| `enabled`   | bool                  | no       | Default `true`. Global on/off; `false` removes the server from every renderer and from consumer secret derivation. |
| `transport` | `"http"` \| `"stdio"` | yes      | Determines which other fields apply.                                                                      |
| `url`       | string                | http     | The MCP endpoint URL.                                                                                     |
| `command`   | string                | stdio    | Executable path, usually a Nix store reference.                                                           |
| `args`      | list of strings       | no       | Stdio only. Defaults to `[]`.                                                                             |
| `auth`      | attrset               | no       | Currently only `{ kind = "bearer"; envVar = "..."; }`. The `envVar` value is a sops secret name.          |
| `oauth`     | attrset               | http     | Pre-registered OAuth client `{ clientId = "..."; callbackPort = <int>; }` for servers without dynamic client registration. Emitted only into Claude Code's config. |
| `startupTimeoutSec` | integer          | no       | Codex startup timeout in seconds.                                                                         |
| `consumers` | attrset               | no       | Per-consumer overrides; see below.                                                                        |

### Per-consumer overrides

| Field                          | Type                                            | Default                              | Notes                                                                                                                                                                                                                                           |
| ------------------------------ | ----------------------------------------------- | ------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `consumers.claudeCode.enabled` | bool                                            | `true`                               | When `false`, the server is omitted from Claude Code output.                                                                                                                                                                                    |
| `consumers.codex.enabled`      | bool                                            | `true`                               | Mirrors OpenCode. When `false`, the server is **still emitted** with `enabled = false` so `codex mcp list` continues to show it, but Codex skips initialising the server.                                                                       |
| `consumers.codex.defaultToolsApprovalMode` | `"auto"` \| `"prompt"` \| `"approve"` | `"approve"`                         | Controls Codex's default approval policy for the server's tools.                                                                                                                                                                               |
| `consumers.opencode.enabled`   | bool                                            | `true`                               | When `false`, the server is **still emitted** with `enabled = false` so the OpenCode TUI can toggle it at runtime.                                                                                                                              |
| `consumers.pi.enabled`         | bool                                            | `true`                               | Mirrors OpenCode. When `false`, the server is **still emitted** with `enabled = false` so Pi's MCP TUI can toggle it at runtime.                                                                                                                |
| `consumers.pi.omit`            | bool                                            | `false`                              | Hard-omits the server from Pi when even a manual toggle would be unsafe or unwanted.                                                                                                                                                            |
| `consumers.pi.directTools`     | bool or list of strings                         | follows `consumers.opencode.enabled` | `true` promotes all tools from that server into Pi's first-class tool list. `false` keeps the server proxy-only through the adapter's `mcp` tool. A list promotes only the named original MCP tools. Disabled Pi servers force this to `false`. |
| `consumers.zed.enabled`        | bool                                            | `true`                               | Mirrors OpenCode. When `false`, the server is **still emitted** with `enabled = false` so Zed's agent panel can toggle it at runtime. Works for stdio, HTTP, and extension-mode servers.                                                        |
| `consumers.zed.mode`           | `"context_server"` \| `"extension"`            | `"context_server"`                   | How Zed installs the server. `"extension"` requires `consumers.zed.id` to name the marketplace slug.                                                                                                                                            |
| `consumers.zed.id`             | string                                          | -                                    | Required when `mode = "extension"`.                                                                                                                                                                                                             |

### Global vs per-consumer disable

Two layers control whether a server reaches a consumer:

- **Global `enabled = false`** - removes the server from every renderer's output and from consumer secret derivation. Use this to retire or pause a server entirely.
- **Per-consumer `consumers.<tool>.enabled = false`** - removes the server from one tool's active runtime surface, or marks it disabled in tools with a toggleable MCP UI. Other tools are unaffected.

Worked example. Setting `servers.context7.consumers.opencode.enabled = false;` removes context7 from OpenCode's runtime tool list (the entry stays in OpenCode's settings with `enabled = false` so it can be toggled back on without a Home Manager run); Claude Code, Codex, and Zed continue to see context7 unchanged. `CONTEXT7_API_KEY` stays declared when at least one enabled consumer still needs it.

The same pattern applies to Zed: `servers.context7.consumers.zed.enabled = false;` keeps the `mcp-server-context7` extension installed and adds a `context_servers."mcp-server-context7" = { enabled = false; settings = {}; }` stub. Zed's agent panel shows the server as a disabled toggleable entry; flipping the toggle in the UI re-enables it without a Home Manager run.

---

## Servers

Five unconditional servers and one conditional server. `On` means enabled by default. `Off` means rendered as disabled where the client supports that state. `Omitted` means the client receives no entry.

| Server       | Transport | Auth   | Claude Code | Codex | OpenCode | Pi      | Zed       | Purpose                                      |
| ------------ | --------- | ------ | ----------- | ----- | -------- | ------- | --------- | -------------------------------------------- |
| `claude`     | stdio     | login  | Omitted     | On    | Off      | Omitted | Off       | Claude Code tools and agent delegation       |
| `codex`      | stdio     | login  | On          | Off   | Off      | Omitted | Off       | Codex tools and agent delegation              |
| `context7`   | HTTP      | bearer | On          | On    | On       | On      | Extension | Live library documentation                   |
| `exa`        | HTTP      | -      | On          | On    | On       | On      | On        | Web search and URL content extraction        |
| `linear`     | HTTP      | bearer | On          | On    | On       | On      | On        | Linear issues, projects, and comments        |
| `slack`      | HTTP      | OAuth  | On          | On    | On       | On      | Off       | Conditional workspace Slack access           |

`claude` and `codex` run as local binaries. The other unconditional servers use remote HTTP. `slack` is a conditional addition.

NixOS MCP is project-owned rather than part of this Home Manager registry. Projects that use it provide the package in their development shell and define their own client configuration.

### Active servers

#### claude

The Claude MCP runs `claude --strict-mcp-config mcp serve` from the direct `pkgs.claude-code` package. It does not use the interactive Claude wrapper. The strict MCP flag prevents the child Claude process from loading configured MCP servers.

Only Codex enables this server. Claude Code omits it to prevent recursive Claude calls. OpenCode and Zed keep disabled entries, while Pi omits it. Codex uses `default_tools_approval_mode = "prompt"`, so every Claude MCP tool call requires approval.

The raw server currently exposes 25 tools, including `Agent`. Claude Code does not provide a server-side tool allowlist for this mode, so the registry cannot expose only `Agent`.

The server uses Claude Code's existing authentication and normal account quota. It adds no repository secret or separate quota. Calls fail when the local login is unavailable or its usage limit is exhausted.

#### context7

Fetches live documentation from official library sources. Given a library name, Context7 resolves the canonical documentation and retrieves the relevant section: current API signatures, option names, and examples rather than the training snapshot. The [Dexter](../assistants/) agent invokes Context7 for every Nix package and option recommendation.

Library APIs change faster than model training cycles. A model asked how to configure a Vite plugin produces a confident but potentially stale answer. A model with Context7 retrieves the answer from current documentation.

Zed installs context7 via the `mcp-server-context7` extension rather than as a context server.

#### exa

Neural semantic search across the web. Unlike keyword search, Exa finds pages semantically related to the query. Useful for finding GitHub discussions, blog posts, and documentation that do not match exact phrase searches. Exa also fetches page content, so it handles both discovery and URL reading.

The configured Exa MCP URL enables three tools:

| Tool                      | Use                                                                                |
| ------------------------- | ---------------------------------------------------------------------------------- |
| `web_search_exa`          | General web search, code search, and current source discovery                      |
| `web_fetch_exa`           | Clean Markdown extraction from one or more known URLs                              |
| `web_search_advanced_exa` | Search with domains, dates, categories, highlights, summaries, or subpage crawling |

Deprecated Exa tools stay disabled. Use `web_search_exa` instead of the old code-context tool, `web_fetch_exa` instead of the old crawling tool, and `web_search_advanced_exa` instead of the old company, people, LinkedIn, and deep-search tools.

#### linear

Linear's official hosted MCP server. It uses Streamable HTTP at `https://mcp.linear.app/mcp` with `LINEAR_API_KEY` bearer authentication. Manual OAuth login is not required.

Linear's MCP tools can read and mutate issues, projects, and comments. The server is active in Claude Code, Codex, OpenCode, Pi, and Zed on every host with those clients. Codex also sets `default_tools_approval_mode = "prompt"` for Linear so tool calls require review instead of inheriting the unattended default.

`LINEAR_API_KEY` reads from `secrets/linear.yaml`. Hosts tagged `workspace` select the `chainguard` key. Other hosts select `wimpysworld`. The existing fish and bash secret exports expose the selected value to coding-agent clients.

#### slack

Slack's official hosted MCP server. It uses Streamable HTTP at `https://mcp.slack.com/mcp`. Slack rejects dynamic client registration, so each supported client receives the public client id `1601185624273.8899143856786` and callback port `3118` from Slack's Claude connection guide.

The server exists only on hosts tagged `workspace`. Claude Code, Codex, OpenCode, and Pi enable it. Zed stays disabled.

After applying Home Manager, sign in once per client and work computer:

| Client      | Login step                                                                                   |
| ----------- | -------------------------------------------------------------------------------------------- |
| Claude Code | Run `claude mcp login slack`.                                                                  |
| Codex       | Run `codex mcp login slack`.                                                                   |
| OpenCode    | Run `opencode mcp auth slack`.                                                                  |
| Pi          | Run `pi`, enter `/mcp`, select `slack`, then press `Ctrl+A` to authenticate.                  |

Each step opens Slack in a browser. Complete the organisation's Okta sign-in and approve the workspace. Claude Code stores credentials in the macOS keychain or its credentials file. Codex's default `auto` MCP OAuth store uses the OS credential store when available and falls back to a local file. OpenCode stores tokens in `~/.local/share/opencode/mcp-auth.json`. Pi stores them in `~/.pi/agent/mcp-oauth/` with mode `0600` on each token file.

No Slack token, environment variable, or secret is declared in this repository.

---

## Platform delivery

`mcp/default.nix` consumes the renderer outputs for enabled clients. Zed and OpenCode are wired here directly when their programs are enabled. Claude Code receives the shared `~/.config/mcp/mcp.json` template only when Claude Code is enabled. Codex and Pi import `servers.nix` directly from their own mixins.

Pi Agent is installed by `../pi` with `pi-mcp-adapter` pinned in the Home Manager-owned `~/.pi/agent/settings.json`. Pi's Home Manager-owned `~/.pi/agent/mcp.json` is self-contained, so default servers do not need the Claude Code `~/.config/mcp/mcp.json` template. The adapter shallow-merges project files by server name, so `piServers` emits full server definitions with Pi-specific `directTools` values rather than partial overrides.

| Platform    | Config path                                                                        | Source                               |
| ----------- | ---------------------------------------------------------------------------------- | ------------------------------------ |
| Claude Code | `~/.config/mcp/mcp.json`                                                           | `claudeServers`                      |
| Pi Agent    | `~/.pi/agent/mcp.json` settings and server definitions                             | `piServers`                          |
| OpenCode    | `~/.config/opencode/settings.json` `mcp` block                                     | `opencodeServers`                    |
| Zed         | `~/.config/zed/settings.json` `context_servers` and `extensions`                   | `zedContextServers`, `zedExtensions` |
| Codex       | `~/.config/codex/config.toml` `[mcp_servers.*]`                                    | `codexServers`                       |

### Platform-specific formats

- **Claude Code** - bearer auth becomes `headers.Authorization = "Bearer ${config.sops.placeholder.<envVar>}"`; the placeholder is interpolated at activation time from the decrypted sops file.
- **Pi Agent** - bearer auth becomes `headers.Authorization = "Bearer ${config.sops.placeholder.<envVar>}"`; the placeholder is interpolated at activation time. Pre-registered OAuth becomes `oauth.clientId` plus an exact `oauth.redirectUri`. Per-server `enabled = false` keeps a server visible in Pi's MCP TUI but disabled by default. Global adapter settings keep the proxy tool enabled and default `directTools`, `autoAuth`, and sampling disabled. Per-server `directTools` follows OpenCode's enabled-by-default preference, but disabled Pi servers force `directTools = false`. Globally disabled servers and `consumers.pi.omit = true` servers are omitted.
- **Codex** - schema strictness rejects unknown fields (`RawMcpServerConfig` uses `deny_unknown_fields`), so `codexServers` only emits accepted keys. Bearer auth becomes `bearer_token_env_var = "<envVar>"`. Pre-registered OAuth becomes `oauth.client_id`; work hosts also set the callback port. Every entry carries `enabled` and `default_tools_approval_mode`; `startup_timeout_sec` is emitted when configured. Flip `consumers.codex.enabled` to `false` to keep the entry visible to `codex mcp list` while skipping initialisation.
- **OpenCode** - bearer auth becomes `headers.Authorization = "Bearer {env:<envVar>}"` (resolved at process start from the shell environment). Pre-registered OAuth becomes `oauth.clientId` plus an exact `oauth.redirectUri`. Stdio `command` is rendered as a list (canonical `command` plus `args` concatenated).
- **Zed** - HTTP servers are wrapped as `npx -y mcp-remote <url>` so Zed can launch them as local processes. Bearer auth adds `--header "Authorization: Bearer ${<envVar>}"`; `mcp-remote` resolves the environment reference at process start. Servers tagged `mode = "extension"` install via the marketplace and skip `context_servers` while enabled. Every emitted entry carries an `enabled` field (default `true`); flip `consumers.zed.enabled` to `false` to disable a server without removing it from the config. Extension-mode servers gain a stub `context_servers` entry (`{ enabled = false; settings = {}; }`) under the same name when disabled, which is how Zed's `Extension` settings variant is identified.

---

## Secrets

Enabled clients drive `sops.secrets` and the shell init exports.

### `requiredSecretsForConsumers` (derived)

Computed from the `auth.envVar` values needed by the enabled consumers. Today this resolves to `["CONTEXT7_API_KEY", "LINEAR_API_KEY"]` for clients that consume context7 and Linear. Disabled servers do not contribute, so flipping a server's global `enabled` flag automatically adds or removes its secrets from this list.

Per-consumer hard omissions gate inclusion for that consumer. Toggleable disabled entries still count for clients that render them as visible but disabled.

### Workflow shell secrets

`SEMGREP_APP_TOKEN` is exported for Codex and Pi agent workflows. It is not tied to an MCP server.

The union (`allSecrets`) drives both `sops.secrets = lib.genAttrs allSecrets ...` and the fish/bash shell init blocks. A developer server with Codex and Pi receives the MCP secrets those clients need plus `SEMGREP_APP_TOKEN`; workstation clients add their own needs when enabled.

### How secrets reach each platform

- **Claude Code** - `config.sops.placeholder.*` injects the decrypted value directly into the generated JSON at Home Manager activation. No environment variable is read at runtime.
- **Pi Agent** - `config.sops.placeholder.*` injects the decrypted value directly into the generated JSON at Home Manager activation.
- **Codex** - `bearer_token_env_var = "<NAME>"` tells Codex which env var to read at process start.
- **OpenCode** - `{env:<NAME>}` placeholder resolved at process start from the shell environment.
- **Zed** - `mcp-remote` resolves `${<NAME>}` in its bearer header from the process environment.
- **Shell** - fish `shellInit` and bash `initExtra` export each secret by reading its sops-managed path. This makes the env vars available to OpenCode, Codex, and any other tool launched from a shell.

Edit shared secrets with `sops secrets/mcp.yaml` and Linear keys with `sops secrets/linear.yaml`. Re-activate with `just home` after changes.

---

## Adding a server

One entry in `servers.nix` is enough. Renderers and `requiredSecretsForConsumers` pick up the change automatically; `mcp/default.nix` does not need editing for the server itself.

### HTTP server with bearer token

```nix
my-server = {
  transport = "http";
  url = "https://example.com/mcp";
  auth = {
    kind = "bearer";
    envVar = "MY_API_KEY";
  };
  consumers = {
    # Optional. Defaults: claudeCode/codex/opencode enabled, zed.mode = "context_server".
    zed.mode = "context_server";
  };
};
```

### HTTP server with no auth

```nix
my-server = {
  transport = "http";
  url = "https://example.com/mcp";
};
```

### Stdio server

```nix
my-server = {
  transport = "stdio";
  command = "${pkgs.my-mcp-package}/bin/my-mcp";
  args = [ "--flag" "value" ];
  consumers.zed.mode = "context_server";
};
```

### Server installed via Zed extension

```nix
my-server = {
  transport = "http";
  url = "https://example.com/mcp";
  consumers.zed = {
    mode = "extension";
    id = "my-server-extension-id";
  };
};
```

### If the server needs a secret

The renderer reads the secret from `auth.envVar`, but the secret itself still needs to exist in sops:

1. Add the key to `secrets/mcp.yaml` via `sops secrets/mcp.yaml`
2. `requiredSecretsForConsumers` picks it up automatically; no changes to `mcp/default.nix` are needed

If the secret should also be exported to the shell when no MCP server uses it directly, add it to `workflowShellSecrets` in `mcp/default.nix`.

Run `just home` to activate.
