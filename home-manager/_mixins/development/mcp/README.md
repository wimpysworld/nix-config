# MCP Servers

Five MCP servers providing AI agents with current, authoritative reference material. Defined once in `servers.nix`, distributed to Claude Code, OpenCode, Zed, Codex, and generic MCP clients.

The Nix composition is the delivery mechanism, not the strategy. The servers here are information retrieval tools: documentation search, web reading, and package lookup. None orchestrate external systems or write to remote APIs. The practical reason: a language model with a training cutoff hallucinates library APIs that changed after the cutoff. A model that fetches live documentation does not need to guess.

## Contents

- [Servers](#servers)
- [Platform Delivery](#platform-delivery)
- [Secrets](#secrets)
- [Adding a Server](#adding-a-server)

---

## Servers

| Server | Transport | Auth | Purpose |
|--------|-----------|------|---------|
| `context7` | HTTP | API key | Live library documentation from official sources |
| `exa` | HTTP | - | Neural web search and URL content extraction |
| `cloudflare` | HTTP | - | Cloudflare product documentation |
| `nixos` | stdio | - | NixOS, Home Manager, nix-darwin package and option search |
| `svelte` | HTTP | - | Svelte documentation and playground |

Four of the five are remote HTTP servers. `nixos` runs as a local binary because no hosted alternative exists.

---

### Context7

Fetches live documentation from official library sources. Given a library name, Context7 resolves the canonical documentation and retrieves the relevant section: current API signatures, option names, and examples rather than the training snapshot. The [Dexter](../assistants/) agent invokes Context7 for every Nix package and option recommendation.

Library APIs change faster than model training cycles. A model asked how to configure a Vite plugin produces a confident but potentially stale answer. A model with Context7 retrieves the answer from current documentation.

---

### Exa

Neural semantic search across the web. Unlike keyword search, Exa finds pages semantically related to the query. Useful for finding GitHub discussions, blog posts, and documentation that do not match exact phrase searches. Exa also fetches page content, so it handles both discovery and URL reading.

The configured Exa MCP URL enables three tools:

| Tool | Use |
|------|-----|
| `web_search_exa` | General web search, code search, and current source discovery |
| `web_fetch_exa` | Clean Markdown extraction from one or more known URLs |
| `web_search_advanced_exa` | Search with domains, dates, categories, highlights, summaries, or subpage crawling |

Deprecated Exa tools stay disabled. Use `web_search_exa` instead of the old code-context tool, `web_fetch_exa` instead of the old crawling tool, and `web_search_advanced_exa` instead of the old company, people, LinkedIn, and deep-search tools.

---

### Cloudflare

Cloudflare's official documentation MCP. Covers Workers, Pages, D1, R2, KV, and Durable Objects. Useful for projects deployed on Cloudflare infrastructure.

Disabled by default in OpenCode (`enabled = false`) where Cloudflare projects are less common than in full AI CLI workflows.

---

### nixos

Searches NixOS packages and options, Home Manager options, and nix-darwin options. Without `mcp-nixos`, agents working in this repository hallucinate option paths and package attribute names. With it, they verify against the actual option set before recommending.

The only stdio server in the configuration. `mcp-nixos` runs as a local binary with no hosted alternative; the Nix package pins it to a Nix store path, so no PATH dependency exists.

---

### Svelte

The official Svelte MCP server, maintained by the Svelte team. Provides documentation, component examples, and playground links directly from the Svelte source.

Disabled by default in OpenCode (`enabled = false`); available as a Zed extension (`svelte-mcp`) in addition to the manual context server entry.

---

## Platform Delivery

`servers.nix` exports shared Claude/generic and OpenCode server sets. `default.nix` writes them to the correct path at activation time via sops templates or Home Manager options. Zed receives its context server config directly from `default.nix`; Codex imports the shared definitions from its own mixin.

| Platform | Config path | Format notes |
|----------|-------------|--------------|
| Claude Code | `~/.config/mcp/mcp.json` | `mcpServers` key, HTTP or stdio |
| OpenCode | `~/.config/opencode/settings.json` `mcp` block | `{env:VAR}` syntax for secrets; `remote`/`local` types |
| Zed | `~/.config/zed/settings.json` `context_servers` | `command`/`args` format; Context7 and Svelte via extensions |
| Codex | `~/.config/codex/config.toml` | Translated in the Codex mixin from shared definitions |

### Platform differences

**OpenCode** resolves secrets via `{env:VAR}` at startup. The shell init for both fish and bash exports each secret by reading its sops-managed path at shell start, making the variables available when OpenCode launches.

**Zed** receives three servers via `context_servers` (cloudflare, exa, nixos). Context7 and Svelte are delivered as Zed extensions instead, which provide tighter editor integration.

---

## Secrets

Six secrets are stored encrypted in `secrets/mcp.yaml`, managed by sops. Only `CONTEXT7_API_KEY` is used by active MCP server configuration.

| Secret | Used by |
|--------|---------|
| `CONTEXT7_API_KEY` | context7 |
| `FIRECRAWL_API_KEY` | firecrawl (disabled) |
| `GOOGLE_CSE_API_KEY` | mcp-google-cse (disabled) |
| `GOOGLE_CSE_ENGINE_ID` | mcp-google-cse (disabled) |
| `JINA_API_KEY` | jina (disabled) |
| `SEMGREP_APP_TOKEN` | semgrep tooling (not wired to any MCP server) |

Secrets reach each platform differently:

- **Claude Code** - `config.sops.placeholder.*` injects the decrypted secret value directly into the JSON template at Home Manager activation
- **OpenCode** - shell exports the secret path; `{env:VAR}` resolved at startup from the environment

Edit secrets with `sops secrets/mcp.yaml`. Re-activate with `just home` after changes.

### Disabled servers

Three servers are present but commented out:

- **firecrawl** - web scraping and crawling. Commented out because Exa covers the primary use case without the additional API dependency.
- **jina** - web reading and screenshots. Commented out because Exa covers search and URL content extraction.
- **mcp-google-cse** - Google Custom Search Engine. Commented out because Exa's semantic search covers the same need with better results for technical queries.

---

## Adding a Server

Add an entry to `mcpServers` and `opencodeServers` in `servers.nix`. Add a Zed entry in `default.nix` if the server should be available there.

**HTTP server with a bearer token:**

```nix
# mcpServers
my-server = {
  type = "http";
  url = "https://example.com/mcp";
  headers.Authorization = "Bearer ${config.sops.placeholder.MY_API_KEY}";
};

# opencodeServers
my-server = {
  type = "remote";
  url = "https://example.com/mcp";
  headers.Authorization = "Bearer {env:MY_API_KEY}";
};

```

If the server needs a secret:

1. Add the key to `secrets/mcp.yaml` via `sops secrets/mcp.yaml`
2. Declare it under `sops.secrets` in `default.nix`
3. Add the shell export to both the fish `shellInit` and bash `initExtra` blocks in `default.nix`

Run `just home` to activate.
