# The Cauldron - Deployment Plan

> This is a work in progress. Technology noted as planned has not yet been set up or configured.

## Project Overview

An AI agent system built around Sith-themed identities, designed for autonomous GitHub project management, research, blog drafting, and report preparation. The active agent is **Darth Traya**, running as two identical instances on separate physical hosts. Both instances are for personal use only.

## The Agents

Three GitHub accounts named after female Sith Lords, operating under a shared GitHub organisation:

| Agent | GitHub account | Telegram bot | Role | Status |
|---|---|---|---|---|
| Darth Traya | `sith-traya` | `@TrayaSithbot` | Commanding agent | Active - master/padawan deployment |
| Darth Skrye | `sith-skrye` | `@SkryeSithbot` | Future subordinate agent | Reserved |
| Darth Zannah | `sith-zannah` | `@ZannahSithbot` | Future subordinate agent | Reserved |

- **GitHub org**: [`the-cauldron`](https://github.com/the-cauldron)
- **Domain**: `darth.cc` - email aliases `traya@darth.cc`, `skrye@darth.cc`, `zannah@darth.cc` route to the owner
- **Chat client**: Telegram

## Research Required

The following decisions are deferred pending research:

| Question | Options | Notes |
|---|---|---|
| Agent software | **ZeroClaw** - decided. See [PICO-vs-ZERO.md](PICO-vs-ZERO.md) | Evaluated against picoclaw; ZeroClaw wins on memory, model routing, web UI, and Copilot Pro support |
| Messaging platform | **Telegram** - decided. See [TELEGRAM-vs-DISCORD.md](TELEGRAM-vs-DISCORD.md) | Long polling only; Discord evaluated and set aside |
| GitHub tooling | [github-mcp-server](https://github.com/github/github-mcp-server) vs `gh` CLI | `sith-traya` account created; defer wiring until GitHub integration phase |

## Infrastructure

### Hardware

Two Framework Desktop mainboard-based workstations, each with:

- **CPU**: AMD Ryzen AI Max 395+ (Strix Halo)
- **RAM**: 128GB unified LPDDR5X (~270 GB/s bandwidth)
- **OS**: NixOS
- **Network**: Standard internet; outbound only from nspawn containers

| Instance | Role | Location |
|---|---|---|
| **master** | Active | Home office |
| **padawan** | Warm standby | Remote office |

Both hosts run identical NixOS configurations. Data is synced between them to support failover; the mechanism for this sync is not yet specified.

### Key Software

- **Agent software**: ZeroClaw - see [PICO-vs-ZERO.md](PICO-vs-ZERO.md) for the evaluation
- **Local inference**: `llama-server`/`llama-swap` (Vulkan); Ollama retained for model downloads and embedding serving during transition
- **Messaging**: Telegram - see [TELEGRAM-vs-DISCORD.md](TELEGRAM-vs-DISCORD.md) for the evaluation
- **CI/cache**: FlakeHub - CI builds and caches all packages

## Architecture Decisions

### 1. Containerisation: NixOS systemd-nspawn containers

**Decision**: Use NixOS declarative containers (`containers.<name>`) backed by systemd-nspawn.

**Rationale**: Deepest Nix integration available. Container config is a NixOS module, rebuilt with `nixos-rebuild switch`. Provides filesystem, process, and network namespace isolation. The agent's own exec guard is explicitly not a full sandbox (cannot inspect child processes from build tools), so container isolation fills this gap.

**Implementation**:
- Each host runs one agent container (`zeroclaw-traya`)
- `privateNetwork = true` with NAT for outbound API/messaging access
- Bind-mount only specific directories the agent needs (read-only where possible)
- Agent runs as a systemd service inside the container

### 2. Local Models + Frontier Fallback

**Decision**: Run inference on each host bare-metal (not containerised). The agent container connects to the inference server over the private network interface.

**Rationale**: GPU/memory-intensive inference should not be containerised. 128 GB unified memory on Strix Halo can load models up to ~120B parameters.

**Target inference backend**: `llama-server`/`llama-swap` (Vulkan) is the primary inference backend, selected on measured throughput advantages over Ollama. The switch is a config-only change - no agent code changes are needed, as both backends expose the same OpenAI-compatible API. Ollama remains in use for some transition work. See [OLLAMA-vs-LLAMACPP.md](OLLAMA-vs-LLAMACPP.md) for the performance case.

**Model pre-seeding**: inference-tagged hosts now enable `llama-models-preseed.service`. The unit derives the host model set from the shared llama policy, resolves each authoritative `repo:quant` reference through the download metadata map, downloads missing GGUF files with `hf download`, and verifies every declared shard before later runtime wiring.

**Shared cache root**: pre-seeded models live under `/var/lib/llama-models/huggingface`. This keeps model state out of user home directories and gives predictable restart behaviour.

**Configuration pattern** (`~/.zeroclaw/config.toml`):
```toml
[[model_list]]
model_name = "primary"
model = "ollama/qwen3-coder-next"
api_base = "http://<host-container-ip>:11434/v1"

[[model_list]]
model_name = "general"
model = "ollama/qwen3.5:35b-a3b"
api_base = "http://<host-container-ip>:11434/v1"

[[model_list]]
model_name = "small"
model = "ollama/gemma4:e4b"
api_base = "http://<host-container-ip>:11434/v1"

[[model_list]]
model_name = "frontier"
model = "anthropic/claude-sonnet-4-5"

[agents.defaults.model]
primary = "primary"
fallbacks = ["frontier"]

[memory]
embedding_model = "ollama/qwen3-embedding:4b-q8_0"
embedding_base = "http://<host-container-ip>:11434/v1"
```

See [OLLAMA-vs-LLAMACPP.md](OLLAMA-vs-LLAMACPP.md) for the full model selection rationale, hardware benchmarks, and backend comparison. The failover chain retries on 429/rate-limit/timeout errors automatically.

**Inference host operations**:
- `llama-models-preseed.service` is present only on hosts tagged `inference`
- The service runs as a root `Type=oneshot` unit after `network-online.target`
- A successful run leaves the selected models ready in `/var/lib/llama-models/huggingface`
- A failed run stops at the preseed stage and reports the broken model reference or shard in the journal
- Inspect status with `systemctl status llama-models-preseed.service`
- Inspect logs with `journalctl -u llama-models-preseed.service`
- Start or rerun manually with `systemctl start llama-models-preseed.service`

### 3. Master/Padawan Instances

**Decision**: Traya runs as two identical instances - master (active) and padawan (warm standby) - on separate physical hosts. Data is synced between them to support failover.

**Rationale**: Warm standby with synced data provides continuity if one host fails without requiring a cold restart from scratch.

**Each instance has its own**:
- Data directory
- Config and security files
- Messaging bot token (separate BotFather tokens)
- Workspace files: `IDENTITY.md`, `SOUL.md`, `USER.md`, `AGENT.md`, `HEARTBEAT.md`
- GitHub bot account: `sith-traya`

The data sync mechanism between master and padawan is not yet specified.

### 4. Workspace Files: Nix-Declared

**Decision**: All workspace personality/configuration files (`USER.md`, `SOUL.md`, `IDENTITY.md`, `AGENT.md`) are declared in Nix, not manually created or synced.

**Rationale**: Version-controlled, reproducible, no drift. ZeroClaw detects changes to these files via mtime tracking at runtime - no restart needed after `nixos-rebuild switch`.

**Implementation**: Nix module with parameters for agent name and role:

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

**Decision**: Telegram is the sole human-agent interface. See [TELEGRAM-vs-DISCORD.md](TELEGRAM-vs-DISCORD.md) for the full evaluation.

Webhook-based integrations from external services (GitHub, Grafana, uptime monitors) will use a lightweight HTTP-to-Telegram bridge when needed. The bridge receives HTTP POSTs from external services and relays them to the appropriate Telegram topic via `sendMessage`.

**Implementation**:
- Separate BotFather token per instance (`@TrayaSithbot` for master, padawan token TBD)
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

**Decision**: Traya holds scoped PATs for the owner's personal projects (contributions via pull requests or carefully constrained actions) and full permissions inside the `the-cauldron` org (create, fork, experiment freely). GitHub integration is deferred until the GitHub tooling phase.

**Research required - GitHub MCP vs `gh` CLI**:

| Option | Notes |
|---|---|
| [github/github-mcp-server](https://github.com/github/github-mcp-server) | Official MCP server; HTTP transport; fine-grained PAT; structured tool calls for issues, PRs, code |
| `gh` CLI | Already Nix-packaged; scriptable; agents can invoke it via exec tool; no MCP overhead |

GitHub MCP is cleaner for agents that interact with GitHub as a structured API. `gh` is simpler to provision inside the container and requires no additional MCP server process. Decision pending.

**When implemented** (regardless of method):
- Fine-grained PAT for `sith-traya`, scoped to specific personal repositories
- Permissions: issues read/write, PRs read/write, contents read
- Full permissions within the `the-cauldron` org
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
| GitHub credentials | Scoped PATs for `sith-traya` | Scoped access to owner projects; full access within `the-cauldron` org |
| Exec tool | **Enabled** | Scoped to container filesystem only |
| Cron tool | **Enabled** | Heartbeat tasks defined in `HEARTBEAT.md` |

**Phased rollout**:

| Phase | Scope | Tools Enabled |
|---|---|---|
| 1 | Research: choose agent software and messaging platform | - |
| 2 | Single ZeroClaw instance (master), messaging, local model | Chat, exec, cron |
| 3 | Add MCP servers (context7, exa, jina, nixos) | Search, read web pages, docs |
| 4 | Add GitHub tooling (read-only PAT) | Review PRs, read issues |
| 5 | Upgrade PAT to write | Comment on PRs, propose fixes |
| 6 | Add workspace file tools + heartbeat tasks | Scheduled reviews, blog post drafts |
| 7 | Bring up padawan instance | Mirror setup, warm standby |

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

- **Syncthing**: Nix handles shared configuration. Data sync between master and padawan is a separate concern, mechanism TBD.
- **Discord**: Evaluated and set aside. Telegram covers all interaction needs; webhook integrations will use a lightweight bridge service rather than maintaining a second chat platform.
- **Agent-to-agent (A2A) protocol**: Skrye and Zannah are reserved for future activation. A2A between Traya master/padawan is not required - they are identical standby instances, not collaborating agents. ZeroClaw's A2A feature (#3566) is worth monitoring for future use once subordinate agents are activated.
- **OCI containers (Docker/Podman)**: Evaluated and rejected in favour of systemd-nspawn for deeper Nix integration.
- **ClawHub skills marketplace**: Not evaluated for security. Install skills from trusted sources only.
- **Agent role definitions**: Martin will determine specific agent roles and heartbeat tasks during deployment.

## Future Expansion

Skrye and Zannah are reserved for future activation as subordinate agents, potentially cloud-based, commanded by Traya. The hierarchy mirrors the Sith Triumvirate from which they draw their names. No deployment work is planned for either until Traya's master/padawan setup is stable.

## Key References

| Resource | URL |
|---|---|
| picoclaw GitHub (evaluated, not used) | https://github.com/sipeed/picoclaw |
| zeroclaw GitHub | https://github.com/zeroclaw-labs/zeroclaw |
| NixOS Containers Wiki | https://wiki.nixos.org/wiki/NixOS_Containers |
| Framework Desktop ML Benchmarks | https://frame.work/nl/en/desktop?tab=machine-learning |
| AMD ROCm for Radeon/Ryzen | https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/ |
| Telegram vs Discord evaluation | [TELEGRAM-vs-DISCORD.md](TELEGRAM-vs-DISCORD.md) |
| Backend comparison and model selection | [OLLAMA-vs-LLAMACPP.md](OLLAMA-vs-LLAMACPP.md) |

*ZeroClaw configuration reference: see PICO-vs-ZERO.md for the full evaluation.*
