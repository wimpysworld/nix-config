# MCP Servers

Eight MCP servers providing AI agents with current, authoritative reference material. Defined once in `servers.nix`, distributed to Claude Code, VSCode, GitHub Copilot CLI, OpenCode, oterm, and Zed by `default.nix`.

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
| `exa` | HTTP | - | Neural web search |
| `github` | HTTP | Bearer | Repository search, file and issue access |
| `jina` | HTTP | API key | Web reader and URL content extraction |
| `cloudflare` | HTTP | - | Cloudflare product documentation |
| `goreleaser` | stdio | - | GoReleaser configuration validation and documentation |
| `nixos` | stdio | - | NixOS, Home Manager, nix-darwin package and option search |
| `svelte` | HTTP | - | Svelte documentation and playground |

Six of the eight are remote HTTP servers. `nixos` and `goreleaser` run as local binaries because no hosted alternatives exist.

---

### Context7

Fetches live documentation from official library sources. Given a library name, Context7 resolves the canonical documentation and retrieves the relevant section: current API signatures, option names, and examples rather than the training snapshot. The [Dexter](../assistants/) agent invokes Context7 for every Nix package and option recommendation.

Library APIs change faster than model training cycles. A model asked how to configure a Vite plugin produces a confident but potentially stale answer. A model with Context7 retrieves the answer from current documentation.

---

### Exa

Neural semantic search across the web. Unlike keyword search, Exa finds pages semantically related to the query. Useful for finding GitHub discussions, blog posts, and documentation that do not match exact phrase searches. Pairs with Jina: Exa identifies which page answers a question; Jina retrieves its content.

---

### GitHub

GitHub's official MCP server via the Copilot API. Provides repository search, file content retrieval, and issue and pull request access. The primary use is reading: inspecting a library's source, locating a relevant issue thread, or checking what a function actually does in a dependency.

GitHub is disabled in the Copilot CLI configuration because Copilot already provides GitHub access natively.

---

### Jina

Fetches a URL and returns clean extracted text. Handles web pages, PDFs, and screenshots. Several tools are excluded via URL parameters, stripping the academic search tools (arXiv, SSRN) and duplicate utilities that add noise without benefit for software development tasks.

Jina fills the gap between knowing which page answers a question and reading what it says.

---

### Cloudflare

Cloudflare's official documentation MCP. Covers Workers, Pages, D1, R2, KV, and Durable Objects. Useful for projects deployed on Cloudflare infrastructure.

Disabled by default in OpenCode (`enabled = false`) where Cloudflare projects are less common than in full AI CLI workflows.

---

### GoReleaser

Validates GoReleaser configurations, flags deprecated options with fix instructions, and serves embedded GoReleaser documentation. Agents working on Go projects with `.goreleaser.yaml` files get current schema validation and migration guidance without relying on training data that may predate the latest GoReleaser release.

The second stdio server in the configuration. `goreleaser-mcp` runs as a local binary packaged in `pkgs/goreleaser-mcp/`; the Nix store path eliminates any PATH dependency.

---

### nixos

Searches NixOS packages and options, Home Manager options, and nix-darwin options. Without `mcp-nixos`, agents working in this repository hallucinate option paths and package attribute names. With it, they verify against the actual option set before recommending.

One of two stdio servers in the configuration. `mcp-nixos` runs as a local binary with no hosted alternative; the Nix package pins it to a Nix store path, so no PATH dependency exists.

---

### Svelte

The official Svelte MCP server, maintained by the Svelte team. Provides documentation, component examples, and playground links directly from the Svelte source.

Disabled by default in OpenCode (`enabled = false`); available as a Zed extension (`svelte-mcp`) in addition to the manual context server entry.

---

## Platform Delivery

`servers.nix` exports four named attribute sets. `default.nix` writes each to the correct path at activation time via sops templates (for secrets injection) or Home Manager options (for Zed and OpenCode).

| Platform | Config path | Format notes |
|----------|-------------|--------------|
| Claude Code | `~/.config/mcp/mcp.json` | `mcpServers` key, HTTP or stdio |
| VSCode | `~/.config/Code/User/mcp.json` (Linux) / `~/Library/Application Support/Code/User/mcp.json` (macOS) | `servers` key, not `mcpServers` |
| Copilot CLI | `~/.config/.copilot/mcp-config.json` | stdio only; HTTP servers proxied via `npx mcp-remote` |
| OpenCode | `~/.config/opencode/settings.json` `mcp` block | `{env:VAR}` syntax for secrets; `remote`/`local` types |
| oterm | `~/.local/share/oterm/config.json` | Separate `auth { type = "bearer"; }` block for tokens |
| Zed | `~/.config/zed/settings.json` `context_servers` | `command`/`args` format; Context7 and Svelte via extensions |

### Platform differences

**Copilot CLI** accepts only stdio servers. Every HTTP server is wrapped with `npx mcp-remote <url>`, which proxies the HTTP transport over stdio. This adds a Node.js subprocess per server but requires no changes to the server configuration itself.

**OpenCode** resolves secrets via `{env:VAR}` at startup. The shell init for both fish and bash exports each secret by reading its sops-managed path at shell start, making the variables available when OpenCode launches.

**VSCode** expects a `servers` top-level key where every other platform uses `mcpServers`. The content is otherwise identical. VSCode also receives a separate `userSettings` block that enables the MCP gallery and configures auto-start.

**Zed** receives five servers via `context_servers` (cloudflare, exa, goreleaser, nixos, jina). Context7 and Svelte are delivered as Zed extensions instead, which provide tighter editor integration.

---

## Secrets

Seven secrets stored encrypted in `secrets/mcp.yaml`, managed by sops:

| Secret | Used by |
|--------|---------|
| `CONTEXT7_API_KEY` | context7 |
| `FIRECRAWL_API_KEY` | firecrawl (disabled) |
| `GITHUB_TOKEN` | github |
| `GOOGLE_CSE_API_KEY` | mcp-google-cse (disabled) |
| `GOOGLE_CSE_ENGINE_ID` | mcp-google-cse (disabled) |
| `JINA_API_KEY` | jina |
| `SEMGREP_APP_TOKEN` | reserved, not yet wired |

Secrets reach each platform differently:

- **Claude Code, VSCode, oterm** - `config.sops.placeholder.*` injects the decrypted secret value directly into the JSON template at Home Manager activation
- **Copilot CLI** - placeholder injected as a CLI flag (`--header`, `--api-key`) passed to the npx subprocess
- **OpenCode** - shell exports the secret path; `{env:VAR}` resolved at startup from the environment

Edit secrets with `sops secrets/mcp.yaml`. Re-activate with `just home` after changes.

### Disabled servers

Two servers are present but commented out:

- **firecrawl** - web scraping and crawling. Commented out because Jina covers the primary use case (single URL reading) without the additional API dependency.
- **mcp-google-cse** - Google Custom Search Engine. Commented out because Exa's semantic search covers the same need with better results for technical queries.

---

## Adding a Server

Add an entry to all four sets in `servers.nix`. The sets differ only in syntax; the server definition is the same concept in each.

**HTTP server with a bearer token:**

```nix
# mcpServers (Claude Code, VSCode)
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

# otermMcpServers
my-server = {
  url = "https://example.com/mcp";
  auth = { type = "bearer"; token = config.sops.placeholder.MY_API_KEY; };
};

# copilotMcpServers
my-server = {
  type = "stdio";
  command = "${pkgs.nodejs_22}/bin/npx";
  args = [
    "-y" "mcp-remote" "https://example.com/mcp"
    "--header" "Authorization: Bearer ${config.sops.placeholder.MY_API_KEY}"
  ];
  tools = [ "*" ];
};
```

If the server needs a secret:

1. Add the key to `secrets/mcp.yaml` via `sops secrets/mcp.yaml`
2. Declare it under `sops.secrets` in `default.nix`
3. Add the shell export to both the fish `shellInit` and bash `initExtra` blocks in `default.nix`

Run `just home` to activate.
