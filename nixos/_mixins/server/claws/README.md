# Claws Deployment Plan

## Project Overview

Ultra-lightweight AI agent (zeroclaw) on two NixOS workstations. The goal is autonomous agents that manage GitHub projects, review PRs, propose fixes, and draft blog posts - running unattended while Martin is busy or sleeping. Both instances are for personal use only.

## Research Required

The following decisions are deferred pending research:

| Question | Options | Notes |
|---|---|---|
| Agent software | **ZeroClaw** - decided. See [PICO-vs-ZERO.md](PICO-vs-ZERO.md) | Evaluated against picoclaw; ZeroClaw wins on memory, model routing, web UI, and Copilot Pro support |
| Messaging platform | **Telegram** - decided. See [TELEGRAM-vs-DISCORD.md](TELEGRAM-vs-DISCORD.md) | Long polling only; Discord evaluated and set aside |
| GitHub tooling | [github-mcp-server](https://github.com/github/github-mcp-server) vs `gh` CLI | sith-skrye, sith-zannah accounts created; defer wiring until GitHub integration phase |

## Infrastructure

### Hardware

Two Framework Desktop mainboard-based workstations, each with:

- **CPU**: AMD Ryzen AI Max 395+ (Strix Halo)
- **RAM**: 128GB unified LPDDR5X (~270 GB/s bandwidth)
- **OS**: NixOS
- **Network**: Standard internet; outbound only from nspawn containers

| Host | Name | Location | Focus |
|---|---|---|---|
| Home workstation | **Skrye** | Home office | Personal projects |
| Remote workstation | **Zannah** | Remote office | Personal projects |

### Key Software

- **Agent software**: ZeroClaw - see [PICO-vs-ZERO.md](PICO-vs-ZERO.md) for the evaluation
- **Local inference**: Ollama (initially); llama.cpp as a future optimisation path
- **Messaging**: Telegram - see [TELEGRAM-vs-DISCORD.md](TELEGRAM-vs-DISCORD.md) for the evaluation
- **CI/cache**: FlakeHub - CI builds and caches all packages

## Architecture Decisions

### 1. Containerisation: NixOS systemd-nspawn containers

**Decision**: Use NixOS declarative containers (`containers.<name>`) backed by systemd-nspawn.

**Rationale**: Deepest Nix integration available. Container config is a NixOS module, rebuilt with `nixos-rebuild switch`. Provides filesystem, process, and network namespace isolation. The agent's own exec guard is explicitly not a full sandbox (cannot inspect child processes from build tools), so container isolation fills this gap.

**Implementation**:
- Each host runs one agent container (`zeroclaw-skrye` on Skrye, `zeroclaw-zannah` on Zannah)
- `privateNetwork = true` with NAT for outbound API/messaging access
- Bind-mount only specific directories the agent needs (read-only where possible)
- Agent runs as a systemd service inside the container

### 2. Local Models + Frontier Fallback

**Decision**: Run Ollama on each host bare-metal (not containerised). The agent container connects to Ollama over the private network interface.

**Rationale**: GPU/memory-intensive inference should not be containerised. Ollama is Nix-packaged (`services.ollama`), provides an OpenAI-compatible API, and ZeroClaw supports it natively. 128GB unified memory on Strix Halo can load models up to ~120B parameters. Benchmarks show 38 tok/s on GPT-OSS 120B and ~65 tok/s on 20B models on this hardware.

**Configuration pattern** (`~/.zeroclaw/config.toml`):
```toml
[[model_list]]
model_name = "local-model"
model = "ollama/qwen3:32b"
api_base = "http://<host-container-ip>:11434/v1"

[[model_list]]
model_name = "frontier-claude"
model = "anthropic/claude-sonnet-4.6"

[agents.defaults.model]
primary = "local-model"
fallbacks = ["frontier-claude"]
```

The failover chain retries on 429/rate-limit/timeout errors automatically.

**Future optimisation**: llama.cpp's `llama-server` can replace Ollama for potentially better performance on Strix Halo's Vulkan backend. The switch is a config-only change - no agent code changes needed.

### 3. Discrete Named Instances

**Decision**: Skrye and Zannah are fully independent agent instances. They share nothing - no workspace, no heartbeat, no memory, no sessions.

**Rationale**: Clean context separation, security isolation (credentials never cross hosts), independent scheduling and behaviour.

**Each instance has its own**:
- Data directory
- Config and security files
- Messaging bot (separate tokens)
- Workspace files: `IDENTITY.md`, `SOUL.md`, `USER.md`, `AGENT.md`, `HEARTBEAT.md`
- GitHub bot account (`sith-skrye` / `sith-zannah`)

### 4. Workspace Files: Nix-Declared

**Decision**: All workspace personality/configuration files (`USER.md`, `SOUL.md`, `IDENTITY.md`, `AGENT.md`) are declared in Nix, not manually created or synced.

**Rationale**: Version-controlled, reproducible, no drift. ZeroClaw detects changes to these files via mtime tracking at runtime - no restart needed after `nixos-rebuild switch`.

**Implementation**: Shared Nix module with parameters for agent name and role, imported by both container configs:

```nix
{ agentName, agentRole, ... }:
{
  environment.etc."claws/workspace/IDENTITY.md".text = ''
    # Identity
    I am ${agentName}, Martin's AI assistant.
    Role: ${agentRole}
  '';
}
```

### 5. Messaging Interface: Telegram

**Decision**: Telegram is the sole human-agent interface and coordination channel between agents. See [TELEGRAM-vs-DISCORD.md](TELEGRAM-vs-DISCORD.md) for the full evaluation.

Webhook-based integrations from external services (GitHub, Grafana, uptime monitors) will use a lightweight HTTP-to-Telegram bridge when needed rather than Discord. The bridge receives HTTP POSTs from external services and relays them to the appropriate Telegram topic via `sendMessage`.

**Implementation**:
- Separate BotFather token per agent (`@SkryeBot`, `@ZannahBot`)
- Long polling only - no webhook, no public endpoint; works behind NAT
- `allow_from` whitelist restricted to Martin's Telegram user ID
- Bot tokens stored in the security config file (not main config), permissions `600`
- Forum-enabled supergroup for shared context; per-topic session isolation via `message_thread_id`

### 6. MCP Tools

**Decision**: The same MCP servers configured for Home Manager development tools (`home-manager/_mixins/development/mcp/`) will be made available inside the claws containers. Server definitions are the source of truth; the Nix module for claws will import or mirror them.

**Rationale**: ZeroClaw has native MCP support (stdio, SSE, HTTP transports). The servers below are already in use across Claude Code, VSCode, OpenCode, and oterm - no new API accounts needed.

**Servers**:

| Server | Transport | Auth | Purpose |
|---|---|---|---|
| `context7` | HTTP | API key | Live library documentation |
| `exa` | HTTP | - | Neural web search |
| `jina` | HTTP | API key | Web reader and URL content extraction |
| `cloudflare` | HTTP | - | Cloudflare product documentation |
| `nixos` | stdio | - | NixOS, Home Manager, nix-darwin option search |
| `svelte` | HTTP | - | Svelte documentation |
| `github` | TBD | PAT | GitHub issues, PRs, code - see §7 |

Most servers are remote HTTP; only `nixos` runs as a local binary (`pkgs.mcp-nixos`). Node.js is not required for any of them. Secrets (Jina API key, Context7 API key) are already in `secrets/ai.yaml` and will be bind-mounted or injected via sops into the container.

**Configuration pattern** (`~/.zeroclaw/config.toml`):
```toml
[tools.mcp]
enabled = true

[tools.mcp.discovery]
enabled = true
ttl = 5
use_bm25 = true

[tools.mcp.servers.exa]
type = "http"
url = "https://mcp.exa.ai/mcp"

[tools.mcp.servers.jina]
type = "http"
url = "https://mcp.jina.ai/v1?..."
headers = { Authorization = "Bearer <JINA_API_KEY>" }

[tools.mcp.servers.context7]
type = "http"
url = "https://mcp.context7.com/mcp"
headers = { Authorization = "Bearer <CONTEXT7_API_KEY>" }

[tools.mcp.servers.cloudflare]
type = "http"
url = "https://docs.mcp.cloudflare.com/mcp"

[tools.mcp.servers.nixos]
type = "stdio"
command = "/path/to/mcp-nixos"
```

Tool discovery enabled so MCP tools are loaded on-demand via BM25 search rather than always in context. This saves tokens when running local models with smaller context windows.

### 7. GitHub Access

**Decision**: Dedicated GitHub bot accounts created for each host (`sith-skrye`, `sith-zannah`). Integration deferred until GitHub tooling phase. Access method TBD (see below).

**Research required - GitHub MCP vs `gh` CLI**:

| Option | Notes |
|---|---|
| [github/github-mcp-server](https://github.com/github/github-mcp-server) | Official MCP server; HTTP transport; fine-grained PAT; structured tool calls for issues, PRs, code |
| `gh` CLI | Already Nix-packaged; scriptable; agents can invoke it via exec tool; no MCP overhead |

GitHub MCP is cleaner for agents that interact with GitHub as a structured API. `gh` is simpler to provision inside the container and requires no additional MCP server process. Decision pending.

**When implemented** (regardless of method):
- Fine-grained PAT for `sith-skrye` / `sith-zannah`, scoped to specific personal repositories
- Permissions: issues read/write, PRs read/write, contents read
- Token stored in security config file (`chmod 600`)
- Start read-only, upgrade to write in a later phase

### 8. Security Posture

**Decision**: Graduated capability rollout. Start locked down, enable tools incrementally.

**Guiding principle**: OpenClaw's security track record (multiple CVEs in weeks, ClawJacked attack, malicious skills in marketplace, log poisoning, exposed instances) informs this posture. ZeroClaw is pre-v1.0 with acknowledged unresolved security issues. The container boundary is the primary safety layer - exec and cron are enabled, but they operate within a sandboxed environment with no host-level privilege.

**Hardening measures**:

| Control | Setting | Notes |
|---|---|---|
| Container isolation | systemd-nspawn | Filesystem, PID, network namespaces; primary safety layer |
| Workspace restriction | `restrict_to_workspace: true` | Default, keep enabled |
| Remote exec | `tools.exec.allow_remote: false` | Blocks shell exec triggered via messaging |
| Messaging allowlist | Martin's user ID only | Only Martin can interact |
| Exec deny patterns | Enabled | Blocks rm -rf, sudo, docker, and similar |
| API key storage | Security config file, `chmod 600` | Separate from main config |
| Sensitive data filtering | `filter_sensitive_data: true` | Prevents LLM seeing its own credentials |
| GitHub credentials | Per-host, scoped PATs | Never cross between Skrye and Zannah |
| Exec tool | **Enabled** | Scoped to container filesystem only |
| Cron tool | **Enabled** | Heartbeat tasks defined in `HEARTBEAT.md` |

**Phased rollout**:

| Phase | Scope | Tools Enabled |
|---|---|---|
| 1 | Research: choose agent software and messaging platform | - |
| 2 | Single ZeroClaw instance (Skrye), messaging, local model | Chat, exec, cron |
| 3 | Add MCP servers (context7, exa, jina, nixos) | Search, read web pages, docs |
| 4 | Add GitHub tooling (read-only PAT) | Review PRs, read issues |
| 5 | Upgrade PAT to write | Comment on PRs, propose fixes |
| 6 | Add workspace file tools + heartbeat tasks | Scheduled reviews, blog post drafts |
| 7 | Replicate to Zannah | Mirror setup, independent agent |

## Nix Packaging

The `llm-agents.nix` flake provides packages for ZeroClaw and related tooling - consistent with how opencode, claude, codex, and similar tools are brought in. CI builds and caches everything via FlakeHub; the Numtide binary cache is not used.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    llm-agents.url = "github:numtide/llm-agents.nix";
  };
}
```

## What Is Not In Scope

- **Syncthing**: Messaging platform handles coordination; Nix handles shared configuration.
- **Discord**: Evaluated and set aside. Telegram covers all interaction needs; webhook integrations will use a lightweight bridge service rather than maintaining a second chat platform.
- **Agent-to-agent (A2A) protocol**: ZeroClaw's A2A feature (#3566) is under review and worth monitoring for future inter-agent delegation between Skrye and Zannah. Not a requirement for initial deployment.
- **OCI containers (Docker/Podman)**: Evaluated and rejected in favour of systemd-nspawn for deeper Nix integration.
- **ClawHub skills marketplace**: Not evaluated for security. Install skills from trusted sources only.
- **Agent role definitions**: Martin will determine specific agent roles and heartbeat tasks during deployment.

## Key References

| Resource | URL |
|---|---|
| picoclaw GitHub (evaluated, not used) | https://github.com/sipeed/picoclaw |
| zeroclaw GitHub | https://github.com/zeroclaw-labs/zeroclaw |
| NixOS Containers Wiki | https://wiki.nixos.org/wiki/NixOS_Containers |
| Framework Desktop ML Benchmarks | https://frame.work/nl/en/desktop?tab=machine-learning |
| AMD ROCm for Radeon/Ryzen | https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/ |
| Telegram vs Discord evaluation | [TELEGRAM-vs-DISCORD.md](TELEGRAM-vs-DISCORD.md) |

*ZeroClaw configuration reference: see PICO-vs-ZERO.md for the full evaluation.*
