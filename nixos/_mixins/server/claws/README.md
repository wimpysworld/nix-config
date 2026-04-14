# The Cauldron - Deployment Plan

> This is a work in progress. Technology noted as planned has not yet been set up or configured.

## Project Overview

An AI agent system built around Sith-themed identities, designed for autonomous GitHub project management, research, blog drafting, and report preparation. The active agent is **Darth Traya**, running on a centralised hub server (Revan) with distributed inference across two Strix Halo workstations connected via Tailscale. All hosts run NixOS. The system is for personal use only.

## The Agents

Three GitHub accounts named after female Sith Lords, operating under a shared GitHub organisation:

| Agent | GitHub account | Telegram bot | Role | Status |
|---|---|---|---|---|
| Darth Traya | `sith-traya` | `@TrayaSithbot` | Commanding agent | Active - Revan hub deployment |
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
| Inference architecture | **Revan hub + Strix Halo inference** - decided. See [OLLAMA-vs-LLAMACPP.md](OLLAMA-vs-LLAMACPP.md) | llama-swap on all hosts; Tailscale mesh; RTX 2000e for embedding |
| GitHub tooling | [github-mcp-server](https://github.com/github/github-mcp-server) vs `gh` CLI | `sith-traya` account created; defer wiring until GitHub integration phase |

## Infrastructure

### Hardware

Three NixOS hosts in a hub-and-spoke topology:

**Revan (hub)** - always-on home server:

| Component | Spec |
|---|---|
| CPU | Intel i9 9900K (downclocked, 65W TDP) |
| RAM | 64 GB |
| GPU | NVIDIA RTX 2000e Ada Generation (16 GB GDDR6 ECC, 50W bus-powered, single-slot, PCIe 4.0 x8) |
| OS | NixOS |
| Role | ZeroClaw host, local embedding/re-ranking, small model for simple tasks, Jellyfin media server |
| Network | LAN (same network as Strix Halo 1) + Tailscale mesh |

The RTX 2000e is Ada Lovelace architecture with 2816 CUDA cores, 88 Gen 4 Tensor cores (71 AI TOPS), 7th-gen NVENC (AV1 encode/decode), and 5th-gen NVDEC. NVENC/NVDEC are dedicated fixed-function silicon separate from CUDA/Tensor cores, so Jellyfin transcoding and llama.cpp inference coexist without compute contention.

**Strix Halo inference hosts (×2)** - dedicated inference workstations:

| Component | Spec |
|---|---|
| CPU | AMD Ryzen AI Max 395+ (Strix Halo) |
| RAM | 128 GB unified LPDDR5X (~270 GB/s bandwidth) |
| OS | NixOS |
| Role | LLM inference via llama-server/llama-swap (Vulkan) |
| Network | Tailscale mesh; Strix Halo 1 also on Revan's LAN |

| Host | Location | Tailscale latency from Revan |
|---|---|---|
| **Strix Halo 1** | Home office (same LAN as Revan) | Sub-millisecond (direct WireGuard tunnel) |
| **Strix Halo 2** | Remote office | Internet-path dependent (direct connection via NAT traversal) |

### Network: Tailscale Mesh

All three hosts join the same Tailnet. The existing Nix Tailscale module auto-registers new hosts via OAuth. Revan's llama-swap uses Tailscale IPs (`100.x.x.x`) for the Strix Halo peer endpoints. Network latency is negligible for LLM inference - token generation time (14-70ms per token on Strix Halo) dwarfs the Tailscale overhead.

### Key Software

| Software | Role | Hosts |
|---|---|---|
| **ZeroClaw** (v0.6.9) | Agent framework | Revan (nspawn container) |
| **llama-swap** (v201) | Model manager / routing proxy | All three hosts (local Nix package) |
| **llama-server** (llama.cpp b8775) | Inference backend | All three hosts (CUDA on Revan, Vulkan on Strix Halos) |
| **Tailscale** | Mesh VPN | All three hosts (auto-registered via OAuth) |
| **Telegram** | Human-agent messaging | Revan (via ZeroClaw) |

See [PICO-vs-ZERO.md](PICO-vs-ZERO.md) for the ZeroClaw evaluation. See [OLLAMA-vs-LLAMACPP.md](OLLAMA-vs-LLAMACPP.md) for the performance case, hardware benchmarks, backend comparison, and full model selection rationale.

## Architecture Decisions

### 1. Containerisation: NixOS systemd-nspawn containers

**Decision**: Use NixOS declarative containers (`containers.<name>`) backed by systemd-nspawn.

**Rationale**: Deepest Nix integration available. Container config is a NixOS module, rebuilt with `nixos-rebuild switch`. Provides filesystem, process, and network namespace isolation. The agent's own exec guard is explicitly not a full sandbox (cannot inspect child processes from build tools), so container isolation fills this gap.

**Implementation**:
- Revan runs one agent container (`zeroclaw-traya`)
- `privateNetwork = true` with NAT for outbound API/messaging access
- Bind-mount only specific directories the agent needs (read-only where possible)
- Agent runs as a systemd service inside the container
- The container connects to Revan's host-side llama-swap instance over the private network interface

### 2. Hub Architecture: Revan + Distributed Inference

**Decision**: Run ZeroClaw on Revan as the central hub. Run embedding, re-ranking (future), and a small local model on Revan's RTX 2000e. Run large inference models on the two Strix Halo workstations. Connect all hosts via Tailscale. Use llama-swap on all three hosts to manage model lifecycle and routing.

**Rationale**: This topology plays to each machine's strengths. Revan is always-on, low-power, and reliable - ideal for hosting the agent process, embedding (zero network hop for RAG retrieval), and a small model for quick tasks. The Strix Halos have 128 GB unified memory each for large MoE models. Both Strix Halos are fully utilised for inference rather than one sitting idle as a warm standby.

**What was traded**: the master/padawan warm-standby topology. ZeroClaw now runs as a single instance. If Revan is unavailable, ZeroClaw must be manually deployed to a Strix Halo as a degraded-mode fallback. NixOS declarative config makes this recovery fast - the same nspawn module applies on any host. Revan's uptime profile (always-on home server, months between reboots, maintenance is scheduled) makes this an acceptable trade for doubled inference capacity.

**Inference backend**: `llama-server` via `llama-swap` (Vulkan on Strix Halo, CUDA on Revan). On Strix Halo, llama.cpp must run with `-fa 1 --mmap 0`. On Revan (RTX 2000e CUDA), standard flags apply; `--mmap 0` is not required.

**Model pre-seeding**: all hosts tagged `inference` (including Revan) enable `llama-models-preseed.service`. The unit derives the host model set from the shared llama policy, resolves each authoritative `repo:quant` reference through the download metadata map, downloads missing GGUF files with `hf download`, and verifies every declared shard before llama-swap starts.

**Shared cache root**: pre-seeded models live under `/var/lib/llama-models/`. This keeps model state out of user home directories and gives predictable restart behaviour.

**Model routing flow**:

1. ZeroClaw sends an API request to Revan's local llama-swap (`http://<host-container-ip>:8080/v1`)
2. llama-swap inspects the `model` field in the request
3. If the model is local (embedding, small model), llama-swap routes to its own llama-server process
4. If the model is served by a Strix Halo peer, llama-swap proxies the request over Tailscale
5. ZeroClaw's `[reliability]` chain handles fallback to cloud providers if local inference is unreachable

**ZeroClaw configuration** (`~/.zeroclaw/config.toml`):

```toml
# --- Provider and default model ---
default_provider = "custom:http://<host-container-ip>:8080/v1"
default_model = "hint:general"

# --- Model routes (hint-based task dispatch) ---
[[model_routes]]
hint = "code"
provider = "custom:http://<host-container-ip>:8080/v1"
model = "qwen3-coder-next"

[[model_routes]]
hint = "general"
provider = "custom:http://<host-container-ip>:8080/v1"
model = "qwen3.5-35b-a3b"

[[model_routes]]
hint = "efficient"
provider = "custom:http://<host-container-ip>:8080/v1"
model = "gemma4-26b"

[[model_routes]]
hint = "media"
provider = "custom:http://<host-container-ip>:8080/v1"
model = "gemma4-e4b"

[[model_routes]]
hint = "simple"
provider = "custom:http://<host-container-ip>:8080/v1"
model = "qwen3-1.7b"

[[model_routes]]
hint = "cloud"
provider = "opencode"
model = "opencode-zen"

[[model_routes]]
hint = "frontier"
provider = "anthropic"
model = "claude-sonnet-4-6"

# --- Embedding routes ---
[memory]
backend = "sqlite"
embedding_model = "hint:local-embed"

[[embedding_routes]]
hint = "local-embed"
provider = "custom:http://<host-container-ip>:8080/v1"
model = "qwen3-embedding-4b"
dimensions = 4096

# --- Query classification (automatic hint routing) ---
[query_classification]
enabled = true

[[query_classification.rules]]
hint = "code"
patterns = ["```", "fn ", "def ", "func ", "class "]
priority = 10

[[query_classification.rules]]
hint = "general"
keywords = ["explain", "analyze", "research", "compare", "write", "draft"]
min_length = 100
priority = 5

[[query_classification.rules]]
hint = "simple"
max_length = 50
priority = 1

# --- Reliability and fallback ---
[reliability]
fallback_providers = ["opencode", "anthropic"]
provider_retries = 2
provider_backoff_ms = 500

[reliability.model_fallbacks]
"qwen3-coder-next" = ["qwen3.5-35b-a3b"]
"qwen3.5-35b-a3b" = ["gemma4-26b"]
"gemma4-26b" = ["qwen3.5-35b-a3b"]

# --- Pacing for local inference ---
[pacing]
step_timeout_secs = 120
```

See [OLLAMA-vs-LLAMACPP.md](OLLAMA-vs-LLAMACPP.md) §9 for the full llama-swap configurations, model distribution per host, and rationale per model slot.

**Inference host operations**:
- `llama-models-preseed.service` is present on all three hosts
- The service runs as a root `Type=oneshot` unit after `network-online.target`
- A successful run leaves the selected models ready in `/var/lib/llama-models/`
- A failed run stops at the preseed stage and reports the broken model reference or shard in the journal
- Inspect status with `systemctl status llama-models-preseed.service`
- Inspect logs with `journalctl -u llama-models-preseed.service`
- Start or rerun manually with `systemctl start llama-models-preseed.service`

### 3. Model Tier Strategy

**Decision**: Four tiers of model access, routed automatically by ZeroClaw's `[[model_routes]]` hints and `[query_classification]`.

| Tier | Where | Models | Use |
|---|---|---|---|
| **Local (Revan)** | RTX 2000e, CUDA | qwen3-embedding:4b-q8_0, qwen3:1.7b | Embedding, re-ranking (future), simple tasks |
| **Inference (Strix Halos)** | iGPU, Vulkan, via Tailscale | qwen3-coder-next, qwen3.5:35b-a3b, gemma4:26b, gemma4:e4b | Coding, reasoning, audio/vision, general tasks |
| **Cloud fallback** | OpenCode Zen | opencode-zen | When local inference is unreachable |
| **Frontier** | Anthropic | claude-sonnet-4-6 | Complex reasoning, deep research |

ZeroClaw's `[reliability]` section handles automatic failover across tiers. The `[query_classification]` rules automatically select the appropriate model hint based on message content - no manual model selection required for routine use.

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
- BotFather token for `@TrayaSithbot`
- Long polling only - no webhook, no public endpoint; works behind NAT
- `allow_from` whitelist restricted to Martin's Telegram user ID
- Bot token stored in the security config file (not main config), permissions `600`
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
| Tailscale mesh | WireGuard encryption | All inter-host inference traffic encrypted in transit |

**Phased rollout**:

| Phase | Scope | Tools Enabled |
|---|---|---|
| 1 | Research: choose agent software and messaging platform | - |
| 2 | Deploy Revan hub: llama-swap, RTX 2000e, embedding, small model | - |
| 3 | Deploy Strix Halo inference: llama-swap on both hosts, Tailscale mesh | - |
| 4 | Single ZeroClaw instance on Revan, Telegram, model routing | Chat, exec, cron |
| 5 | Add MCP servers (context7, exa, jina, nixos) | Search, read web pages, docs |
| 6 | Add GitHub tooling (read-only PAT) | Review PRs, read issues |
| 7 | Upgrade PAT to write | Comment on PRs, propose fixes |
| 8 | Add workspace file tools + heartbeat tasks | Scheduled reviews, blog post drafts |

## Nix Packaging

The `llm-agents.nix` flake provides packages for ZeroClaw and related tooling - consistent with how opencode, claude, codex, and similar tools are brought in. CI builds and caches everything via FlakeHub; the Numtide binary cache is not used. llama-swap v201 is packaged as a local Nix derivation.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    llm-agents.url = "github:numtide/llm-agents.nix";
  };
}
```

## What Is Not In Scope

- **Syncthing**: Nix handles shared configuration. Revan backup/recovery is a separate concern, mechanism TBD.
- **Discord**: Evaluated and set aside. Telegram covers all interaction needs; webhook integrations will use a lightweight bridge service rather than maintaining a second chat platform.
- **Agent-to-agent (A2A) protocol**: Skrye and Zannah are reserved for future activation. ZeroClaw's A2A feature (#3566) is worth monitoring for future use once subordinate agents are activated.
- **OCI containers (Docker/Podman)**: Evaluated and rejected in favour of systemd-nspawn for deeper Nix integration.
- **ClawHub skills marketplace**: Not evaluated for security. Install skills from trusted sources only.
- **Agent role definitions**: Martin will determine specific agent roles and heartbeat tasks during deployment.
- **Master/padawan topology**: Superseded by the Revan hub architecture. Both Strix Halos are now dedicated inference nodes rather than one sitting idle as a warm standby. If Revan goes down, ZeroClaw can be deployed to either Strix Halo as a degraded-mode fallback using the same Nix config.
- **Ollama**: Transitional. llama-server via llama-swap is the production inference backend on all hosts. Ollama may remain installed for ad-hoc model downloads but is not in the production path.

## Future Expansion

Skrye and Zannah are reserved for future activation as subordinate agents, potentially cloud-based, commanded by Traya. The hierarchy mirrors the Sith Triumvirate from which they draw their names. No deployment work is planned for either until Traya's Revan hub setup is stable.

**Revan GPU headroom**: the RTX 2000e's 16 GB VRAM is lightly utilised (~7 GB for embedding + small model + Jellyfin). Future options include: a larger local model for more capable on-hub inference, a re-ranking model (qwen3-reranker:4b) for improved retrieval quality, or additional embedding models for specialised domains.

**NPU co-processing**: the Strix Halo NPU (40 XDNA2 units) is not yet usable with llama.cpp. Once tooling matures, it could run embedding or small models concurrently with the iGPU, increasing per-host capacity. See [OLLAMA-vs-LLAMACPP.md](OLLAMA-vs-LLAMACPP.md) §10.

## Key References

| Resource | URL |
|---|---|
| picoclaw GitHub (evaluated, not used) | https://github.com/sipeed/picoclaw |
| zeroclaw GitHub | https://github.com/zeroclaw-labs/zeroclaw |
| zeroclaw providers reference | https://github.com/zeroclaw-labs/zeroclaw/blob/master/docs/reference/api/providers-reference.md |
| zeroclaw config reference | https://github.com/zeroclaw-labs/zeroclaw/blob/master/docs/reference/api/config-reference.md |
| llama-swap (v201) | https://github.com/mostlygeek/llama-swap |
| llama-swap configuration docs | https://github.com/mostlygeek/llama-swap/blob/main/docs/configuration.md |
| NixOS Containers Wiki | https://wiki.nixos.org/wiki/NixOS_Containers |
| PNY RTX 2000e Ada Generation | https://www.pny.com/rtx-2000e-ada-generation |
| Framework Desktop ML Benchmarks | https://frame.work/nl/en/desktop?tab=machine-learning |
| AMD ROCm for Radeon/Ryzen | https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/ |
| Tailscale performance best practices | https://tailscale.com/docs/reference/best-practices/performance |
| Telegram vs Discord evaluation | [TELEGRAM-vs-DISCORD.md](TELEGRAM-vs-DISCORD.md) |
| Backend comparison and model selection | [OLLAMA-vs-LLAMACPP.md](OLLAMA-vs-LLAMACPP.md) |

*ZeroClaw configuration reference: see PICO-vs-ZERO.md for the full evaluation.*
