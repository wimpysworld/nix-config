# MCP Servers

Five always-active MCP servers provide AI agents with current reference material. Playwright is emitted only on browser-automation systems. The Chainguard RAG server is emitted only on `bane`. Definitions live once in `servers.nix` and are distributed to Claude Code, OpenCode, Zed, Codex, and generic MCP clients via per-consumer renderers.

The Nix composition is the delivery mechanism, not the strategy. Most servers here are information retrieval tools: documentation search, web reading, and package lookup. Playwright is local browser automation for agent-driven page inspection and only appears when both Chromium and Firefox are enabled under the shared browser automation policy. The practical reason: a language model with a training cutoff hallucinates library APIs that changed after the cutoff. A model that fetches live documentation does not need to guess.

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

| Attribute | Purpose |
|-----------|---------|
| `servers` | Canonical attrset; one entry per MCP server |
| `claudeServers` | Renderer for Claude Code's `mcpServers` and the generic JSON template |
| `codexServers` | Renderer for Codex's `[mcp_servers.*]` TOML tables |
| `opencodeServers` | Renderer for OpenCode's `mcp` settings block |
| `piServers` | Renderer for Pi's `pi-mcp-adapter` server overrides with Pi-native `directTools` |
| `zedContextServers` | Renderer for Zed's `context_servers` setting (stdio + HTTP) |
| `zedExtensions` | Sorted list of Zed extension marketplace ids |
| `zedExtensionDisables` | Stub `context_servers` entries that flip extension-mode servers off |
| `requiredSecrets` | Sorted list of env var names referenced by enabled servers |

Each renderer is a pure function of the canonical `servers` attrset. Adding or modifying a server means editing one entry; the renderers and `requiredSecrets` derivation pick up the change automatically.

---

## Canonical schema

Each entry in `servers` carries the following fields. Only `transport` is mandatory; everything else has sensible defaults or is conditional on transport.

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `enabled` | bool | no | Default `true`. Global on/off; `false` removes the server from every renderer and from `requiredSecrets`. |
| `transport` | `"http"` \| `"stdio"` | yes | Determines which other fields apply. |
| `url` | string | http | The MCP endpoint URL. |
| `command` | string | stdio | Executable path; usually a Nix store reference such as `${pkgs.mcp-nixos}/bin/mcp-nixos`. |
| `args` | list of strings | no | Stdio only. Defaults to `[]`. |
| `auth` | attrset | no | Currently only `{ kind = "bearer"; envVar = "..."; }`. The `envVar` value is a sops secret name. |
| `env` | attrset | no | Stdio env passthrough. Schema is `{ ENV_VAR_IN_PROCESS = "SOPS_SECRET_NAME"; }`. |
| `consumers` | attrset | no | Per-consumer overrides; see below. |

### Per-consumer overrides

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `consumers.claudeCode.enabled` | bool | `true` | When `false`, the server is omitted from Claude Code output. |
| `consumers.codex.enabled` | bool | `true` | Mirrors OpenCode. When `false`, the server is **still emitted** with `enabled = false` so `codex mcp list` continues to show it, but Codex skips initialising the server. |
| `consumers.opencode.enabled` | bool | `true` | When `false`, the server is **still emitted** with `enabled = false` so the OpenCode TUI can toggle it at runtime. |
| `consumers.pi.directTools` | bool or list of strings | follows `consumers.opencode.enabled` | Pi has no per-server `enabled` flag. `true` promotes all tools from that server into Pi's first-class tool list. `false` keeps the server proxy-only through the adapter's `mcp` tool. A list promotes only the named original MCP tools. |
| `consumers.zed.enabled` | bool | `true` | Mirrors OpenCode. When `false`, the server is **still emitted** with `enabled = false` so Zed's agent panel can toggle it at runtime. Works for stdio, HTTP, and extension-mode servers. |
| `consumers.zed.mode` | `"context_server"` \| `"extension"` \| `"skip"` | `"context_server"` | How Zed installs the server. `"extension"` requires `consumers.zed.id` to name the marketplace slug. `"skip"` excludes Zed entirely. |
| `consumers.zed.id` | string | - | Required when `mode = "extension"`. |

### Global vs per-consumer disable

Two layers control whether a server reaches a consumer:

- **Global `enabled = false`** — removes the server from every renderer's output and from `requiredSecrets`. Use this to retire or pause a server entirely.
- **Per-consumer `consumers.<tool>.enabled = false`** — removes the server from one tool's output (or, for OpenCode, marks it disabled within the output). Other tools are unaffected.

Worked example. Setting `servers.context7.consumers.opencode.enabled = false;` removes context7 from OpenCode's runtime tool list (the entry stays in OpenCode's settings with `enabled = false` so it can be toggled back on without a Home Manager run); Claude Code, Codex, and Zed continue to see context7 unchanged. The `CONTEXT7_API_KEY` secret stays in `requiredSecrets` because the server's global `enabled` flag is still `true`.

The same pattern applies to Zed: `servers.context7.consumers.zed.enabled = false;` keeps the `mcp-server-context7` extension installed and adds a `context_servers."mcp-server-context7" = { enabled = false; settings = {}; }` stub. Zed's agent panel shows the server as a disabled toggleable entry; flipping the toggle in the UI re-enables it without a Home Manager run.

---

## Servers

Five always-active servers, two conditional servers, and three disabled placeholders.

| Server | Transport | Auth | Purpose |
|--------|-----------|------|---------|
| `context7` | HTTP | bearer | Live library documentation from official sources |
| `exa` | HTTP | - | Neural web search and URL content extraction |
| `cloudflare` | HTTP | - | Cloudflare product documentation |
| `nixos` | stdio | - | NixOS, Home Manager, nix-darwin package and option search |
| `playwright` | stdio | - | Conditional; browser automation via Playwright MCP; disabled by default where per-server toggles exist |
| `rag` | HTTP | - | Conditional on `bane`; Chainguard RAG search |
| `svelte` | HTTP | - | Svelte documentation and playground |
| `firecrawl` | HTTP | - | Disabled (`enabled = false`); web scraping and crawling |
| `jina` | HTTP | bearer | Disabled; web reading and screenshots |
| `mcpGoogleCse` | stdio | env | Disabled; Google Custom Search Engine |

Four of the always-active servers are remote HTTP. `nixos` runs as a local binary. When enabled, `playwright` also runs as a local binary.

### Active servers

#### context7

Fetches live documentation from official library sources. Given a library name, Context7 resolves the canonical documentation and retrieves the relevant section: current API signatures, option names, and examples rather than the training snapshot. The [Dexter](../assistants/) agent invokes Context7 for every Nix package and option recommendation.

Library APIs change faster than model training cycles. A model asked how to configure a Vite plugin produces a confident but potentially stale answer. A model with Context7 retrieves the answer from current documentation.

Zed installs context7 via the `mcp-server-context7` extension rather than as a context server.

#### exa

Neural semantic search across the web. Unlike keyword search, Exa finds pages semantically related to the query. Useful for finding GitHub discussions, blog posts, and documentation that do not match exact phrase searches. Exa also fetches page content, so it handles both discovery and URL reading.

The configured Exa MCP URL enables three tools:

| Tool | Use |
|------|-----|
| `web_search_exa` | General web search, code search, and current source discovery |
| `web_fetch_exa` | Clean Markdown extraction from one or more known URLs |
| `web_search_advanced_exa` | Search with domains, dates, categories, highlights, summaries, or subpage crawling |

Deprecated Exa tools stay disabled. Use `web_search_exa` instead of the old code-context tool, `web_fetch_exa` instead of the old crawling tool, and `web_search_advanced_exa` instead of the old company, people, LinkedIn, and deep-search tools.

#### cloudflare

Cloudflare's official documentation MCP. Covers Workers, Pages, D1, R2, KV, and Durable Objects. Useful for projects deployed on Cloudflare infrastructure.

Disabled in OpenCode via `consumers.opencode.enabled = false` because Cloudflare projects are less common in OpenCode's workflow than in the full AI CLI tools. The entry remains visible in the OpenCode TUI for ad-hoc enabling.

#### nixos

Searches NixOS packages and options, Home Manager options, and nix-darwin options. Without `mcp-nixos`, agents working in this repository hallucinate option paths and package attribute names. With it, they verify against the actual option set before recommending.

`mcp-nixos` runs as a local binary with no hosted alternative; the Nix package pins it to a Nix store path, so no PATH dependency exists.

#### playwright

Playwright MCP gives agents browser automation for page inspection, navigation, screenshots, and interaction tests. It is configured as a local stdio server using Nixpkgs' `playwright-mcp` package only when browser automation is enabled.

The shared browser automation policy requires both Chromium and Firefox. Servers that do not meet that policy omit Playwright entirely, so generated MCP config does not reference the `playwright-mcp` closure. Where emitted, Codex, OpenCode, and Zed keep the server visible but disabled by default through their per-server `enabled = false` settings. Pi keeps it present but proxy-only with `directTools = false`, since Pi has no per-server `enabled` flag. Claude Code receives the server through the shared `mcpServers` output because its renderer has no visible disabled state.

#### rag

Chainguard RAG is a hosted HTTP MCP server for Chainguard-specific retrieval. It is gated to `bane` via `config.noughty.host.name`, and uses the default enabled state for every renderer: Claude Code and generic clients receive it in `mcpServers`, Codex receives an enabled `[mcp_servers.rag]` table, OpenCode receives an enabled `mcp.rag` entry, Pi promotes it to direct tools, and Zed receives it as an enabled context server.

#### svelte

The official Svelte MCP server, maintained by the Svelte team. Provides documentation, component examples, and playground links directly from the Svelte source.

Disabled in OpenCode via `consumers.opencode.enabled = false`. Zed installs it through the `svelte-mcp` extension rather than as a context server.

### Disabled servers

These three carry `enabled = false` at the top level. They stay declared so re-enabling one is a single edit (flip `enabled` to `true`) without rediscovering URLs or schemas.

- **firecrawl** — web scraping and crawling. Disabled because Exa covers the primary use case. Note that firecrawl embeds the API key in the URL path, which doesn't fit the `auth.kind = "bearer"` shape; re-enabling will need renderer logic to handle URL-embedded secrets.
- **jina** — web reading and screenshots. Disabled because Exa covers search and URL content extraction.
- **mcpGoogleCse** — Google Custom Search Engine. Disabled because Exa's semantic search covers the same need with better results for technical queries.

---

## Platform delivery

`mcp/default.nix` consumes the renderer outputs and writes them to the correct path at activation time. Zed and OpenCode are wired here directly; Claude Code reads via Home Manager's native `programs.claude-code.mcpServers`; Codex's mixin imports `servers.nix` and reads `codexServers`. Pi's mixin imports `servers.nix` and reads `piServers`.

Pi Agent is installed by `../pi` with `pi-mcp-adapter` pinned in the Home Manager-owned `~/.pi/agent/settings.json`. The adapter reads `~/.config/mcp/mcp.json` automatically, then shallow-merges Pi's Home Manager-owned `~/.pi/agent/mcp.json`. Because that merge is shallow by server name, `piServers` emits full server definitions with Pi-specific `directTools` values rather than partial overrides.

| Platform | Config path | Source |
|----------|-------------|--------|
| Claude Code | `~/.config/mcp/mcp.json` | `claudeServers` |
| Pi Agent | `~/.config/mcp/mcp.json` plus `~/.pi/agent/mcp.json` settings and server overrides | `claudeServers` plus `piServers` |
| OpenCode | `~/.config/opencode/settings.json` `mcp` block | `opencodeServers` |
| Zed | `~/.config/zed/settings.json` `context_servers` and `extensions` | `zedContextServers`, `zedExtensions` |
| Codex | `~/.config/codex/config.toml` `[mcp_servers.*]` | `codexServers` |

### Platform-specific shapes

- **Claude Code** — bearer auth becomes `headers.Authorization = "Bearer ${config.sops.placeholder.<envVar>}"`; the placeholder is interpolated at activation time from the decrypted sops file.
- **Pi Agent** — `pi-mcp-adapter` has no per-server `enabled` field. Server presence means Pi can use the server, and servers connect lazily when used. Global adapter settings keep the proxy tool enabled and default `directTools`, `autoAuth`, and sampling disabled. Per-server `directTools` follows OpenCode's enabled-by-default preference: context7, exa, and nixos are promoted to direct tools; cloudflare, svelte, and Playwright remain proxy-only when present. Globally disabled servers are omitted. Playwright is still omitted entirely unless the shared browser automation policy enables both Chromium and Firefox.
- **Codex** — schema strictness rejects unknown fields (`RawMcpServerConfig` uses `deny_unknown_fields`), so `codexServers` only emits keys Codex accepts: `url`, `bearer_token_env_var`, `command`, `args`, `env`, and `enabled`. Bearer auth becomes `bearer_token_env_var = "<envVar>"`. Every entry carries an `enabled` field (default `true`); flip `consumers.codex.enabled` to `false` to keep the entry visible to `codex mcp list` while skipping initialisation.
- **OpenCode** — bearer auth becomes `headers.Authorization = "Bearer {env:<envVar>}"` (resolved at process start from the shell environment). Stdio `command` is rendered as a list (canonical `command` plus `args` concatenated).
- **Zed** — HTTP servers are wrapped as `npx -y mcp-remote <url>` so Zed can launch them as local processes. Servers tagged `mode = "extension"` install via the marketplace and skip `context_servers` while enabled. Every emitted entry carries an `enabled` field (default `true`); flip `consumers.zed.enabled` to `false` to disable a server without removing it from the config. Extension-mode servers gain a stub `context_servers` entry (`{ enabled = false; settings = {}; }`) under the same name when disabled, which is how Zed's `Extension` settings variant is identified.

---

## Secrets

Two sources feed `sops.secrets` and the shell init exports.

### `requiredSecrets` (derived)

Computed from the `auth.envVar` and `env` values of every enabled server in `servers`. Today this resolves to `["CONTEXT7_API_KEY"]` because context7 is the only enabled server with bearer auth. Disabled servers do not contribute, so flipping a server's global `enabled` flag automatically adds or removes its secrets from this list.

Per-consumer overrides do **not** gate inclusion. A server with `consumers.opencode.enabled = false` still ships its secret, because Claude Code or Codex may still consume it.

### `additionalSecrets` (hand-maintained)

Secrets that don't belong to any active MCP server but still need decryption and shell export. Defined in `mcp/default.nix`:

| Secret | Reason it stays declared |
|--------|--------------------------|
| `FIRECRAWL_API_KEY` | Belongs to disabled firecrawl; declared so re-enabling skips a sops-rekey round-trip |
| `GOOGLE_CSE_API_KEY` | Belongs to disabled mcpGoogleCse; same reason |
| `GOOGLE_CSE_ENGINE_ID` | Belongs to disabled mcpGoogleCse; same reason |
| `SEMGREP_APP_TOKEN` | Used by the security scanner skill, not by any MCP server |

The union (`allSecrets`) drives both `sops.secrets = lib.genAttrs allSecrets ...` and the fish/bash shell init blocks. Today this union is `[CONTEXT7_API_KEY, FIRECRAWL_API_KEY, GOOGLE_CSE_API_KEY, GOOGLE_CSE_ENGINE_ID, SEMGREP_APP_TOKEN]`.

### How secrets reach each platform

- **Claude Code** — `config.sops.placeholder.*` injects the decrypted value directly into the generated JSON at Home Manager activation. No environment variable is read at runtime.
- **Codex** — `bearer_token_env_var = "<NAME>"` tells Codex which env var to read at process start.
- **OpenCode** — `{env:<NAME>}` placeholder resolved at process start from the shell environment.
- **Shell** — fish `shellInit` and bash `initExtra` export each secret by reading its sops-managed path. This makes the env vars available to OpenCode, Codex, and any other tool launched from a shell.

Edit secrets with `sops secrets/mcp.yaml`. Re-activate with `just home` after changes.

---

## Adding a server

One entry in `servers.nix` is enough. Renderers and `requiredSecrets` pick up the change automatically; `mcp/default.nix` does not need editing for the server itself.

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

The renderer reads the secret from `auth.envVar` or `env` values, but the secret itself still needs to exist in sops:

1. Add the key to `secrets/mcp.yaml` via `sops secrets/mcp.yaml`
2. The `requiredSecrets` derivation picks it up automatically; no changes to `mcp/default.nix` are needed

If the secret should also be exported to the shell when no MCP server uses it directly (the `SEMGREP_APP_TOKEN` pattern), add the name to `additionalSecrets` in `mcp/default.nix`.

Run `just home` to activate.
