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
| Agent software | **Hermes Agent** - decided. See [PICO-vs-ZERO.md](PICO-vs-ZERO.md) | Originally evaluated PicoClaw vs ZeroClaw; both superseded by Hermes (NousResearch). First-class NixOS module, podman container mode, declarative config, superior memory system. |
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
| Role | Hermes Agent host, local embedding/re-ranking, lightweight local fallback inference, Jellyfin media server |
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

All three hosts join the same Tailnet. The existing Nix Tailscale module auto-registers new hosts via OAuth. Hermes reaches the inference hosts over Tailscale via their MagicDNS names, with one host-local llama-swap instance per inference host. Network latency is negligible for LLM inference - token generation time (14-70ms per token on Strix Halo) dwarfs the Tailscale overhead.

### Key Software

| Software | Role | Hosts |
|---|---|---|
| **Hermes Agent** (v0.9.0) | Agent framework | Revan (NixOS module, podman container) |
| **llama-swap** (v201) | Host-local model manager and on-demand launcher | All inference hosts (local Nix package) |
| **llama-server** (llama.cpp b8775) | Inference backend | All three hosts (CUDA on Revan, Vulkan on Strix Halos) |
| **Tailscale** | Mesh VPN | All three hosts (auto-registered via OAuth) |
| **Telegram** | Human-agent messaging | Revan (via Hermes gateway) |

See [PICO-vs-ZERO.md](PICO-vs-ZERO.md) for the agent software evaluation (PicoClaw, ZeroClaw, and the superseding Hermes decision). See [OLLAMA-vs-LLAMACPP.md](OLLAMA-vs-LLAMACPP.md) for the performance case, hardware benchmarks, backend comparison, and full model selection rationale.

## Architecture Decisions

### 1. Containerisation: Hermes NixOS Module with Podman

**Decision**: Use the Hermes Agent upstream NixOS module (`nixosModules.default`) with podman container mode.

**Rationale**: The Hermes flake exports a comprehensive NixOS module with two deployment modes: native (hardened systemd service) and container (persistent OCI container with `/nix/store` bind-mounted read-only). Container mode with podman provides process and filesystem isolation while the NixOS module handles the full lifecycle declaratively: user creation, config generation, secret injection, service management, GC root protection, and container identity tracking.

This replaces the original plan to use NixOS declarative `containers.<name>` (systemd-nspawn) with a hand-managed agent binary. The Hermes module eliminates all the custom wiring: no manual systemd unit, no nspawn networking config, no NAT rules, no bind-mount declarations. The module does it all.

**Implementation**:
- Revan runs the Hermes service with `container.enable = true` and `container.backend = "podman"`
- `container.hostUsers = [ "martin" ]` creates a `~/.hermes` symlink bridging host CLI to container state
- `addToSystemPackages = true` puts the `hermes` CLI on the host PATH; all commands transparently route into the container
- `container.extraOptions = [ "--network=host" ]` gives the container access to Tailscale addresses
- All configuration is declarative via `settings`, `environmentFiles`, `mcpServers`, and `documents`
- Managed mode blocks CLI config mutation, everything goes through `nixos-rebuild switch`
- The container persists across rebuilds; only image/volume/options changes trigger recreation

**Container architecture**:

| Container path | Host path | Mode | Notes |
|---|---|---|---|
| `/nix/store` | `/nix/store` | `ro` | Hermes binary + all Nix deps |
| `/data` | `/var/lib/hermes` | `rw` | All state, config, workspace |
| `/home/hermes` | `${stateDir}/home` | `rw` | Persistent agent home |
| Writable layer | (podman managed) | `rw` | `apt`/`pip`/`npm` installs; lost on container recreation |

### 2. Hub Architecture: Revan + Distributed Inference

**Decision**: Run Hermes on Revan as the central hub. Run embedding, re-ranking (future), and a small local model on Revan's RTX 2000e. Run large inference models on the two Strix Halo workstations. Connect all hosts via Tailscale. Use one host-local llama-swap on each inference host to manage on-demand model lifecycle.

**Rationale**: This topology plays to each machine's strengths. Revan is always-on, low-power, and reliable - ideal for hosting the agent process, embedding (zero network hop for RAG retrieval), and a small model for quick tasks. The Strix Halos have 128 GB unified memory each for large MoE models. Both Strix Halos are fully utilised for inference rather than one sitting idle as a warm standby.

**What was traded**: the master/padawan warm-standby topology. Hermes now runs as a single instance. If Revan is unavailable, Hermes can be deployed to a Strix Halo as a degraded-mode fallback. The same NixOS module applies on any host - add `services.hermes-agent.enable = true` to the Strix Halo's config and rebuild. Revan's uptime profile (always-on home server, months between reboots, maintenance is scheduled) makes this an acceptable trade for doubled inference capacity.

**Inference backend**: `llama-server` via `llama-swap` (Vulkan on Strix Halo, CUDA on Revan). On Strix Halo, llama.cpp must run with `-fa 1 --mmap 0`. On Revan (RTX 2000e CUDA), standard flags apply; `--mmap 0` is not required. The shared Nix model policy now also sets `--ctx-size`, `--cache-type-k q8_0`, `--cache-type-v q8_0`, and, where sourced, the generation sampler flags per selected model role.

**Model pre-seeding**: all hosts tagged `inference` (including Revan) enable `llama-models-preseed.service`. The unit derives the host model set from the shared llama policy, resolves each authoritative `repo:quant` reference through the download metadata map, downloads missing GGUF files with `hf download`, and verifies every declared shard before llama-swap starts.

**Shared cache root**: pre-seeded models live under `/var/lib/llama-models/`. This keeps model state out of user home directories and gives predictable restart behaviour.

**Model routing flow**:

Hermes provides four complementary routing mechanisms rather than a single automatic classification system:

1. **Smart routing** (automatic): Simple/short messages route to a cheap local model on Revan. Complex messages stay on the default agentic model. This is a binary split based on message length and complexity heuristics, not task classification.
2. **Manual switching**: `/model custom:coding:qwen3-coder-30b-a3b` switches to the coding endpoint mid-session. `/model custom:agentic:qwen3.5-35b-a3b` switches back. `/model anthropic` escalates to cloud.
3. **Delegation**: Subagent tasks (spawned via `delegate_task`) automatically route to a different model/provider, configured globally. Coding subtasks go to the coding endpoint.
4. **Auxiliary models**: Side tasks (vision, web extraction, compression, approvals) each route to a configured endpoint, separate from the main conversation model. These fire automatically.
5. **Fallback**: If the primary model fails (errors, rate limits), Hermes auto-switches to the configured fallback provider (Anthropic). Fires once per session.

Full capability-based routing (issue #157 in the Hermes repo) is a future feature. The current mechanisms cover the common cases; manual `/model` switching handles the rest.

**Hermes NixOS configuration** (Revan's `configuration.nix`):

```nix
{ config, pkgs, inputs, ... }:
{
  # Podman (already in existing NixOS config)
  virtualisation.podman.enable = true;
  virtualisation.docker.enable = false;

  services.hermes-agent = {
    enable = true;

    # --- Container isolation via podman ---
    container = {
      enable = true;
      backend = "podman";
      hostUsers = [ "martin" ];
      extraOptions = [ "--network=host" ];  # Access Tailscale addresses
    };

    addToSystemPackages = true;

    # --- Secrets via sops-nix ---
    environmentFiles = [ config.sops.secrets."hermes-env".path ];

    # --- Agent identity ---
    documents = {
      "SOUL.md" = builtins.readFile ./traya-soul.md;
      "USER.md" = builtins.readFile ./traya-user.md;
    };

    # --- Model and provider configuration ---
    settings = {
      # Default: agentic model on Strix Halo 2
      model = {
        default = "qwen3.5-35b-a3b";
        provider = "custom";
        base_url = "http://zannah.drongo-gamma.ts.net:8080/v1";
      };

      # Named custom providers for /model switching
      custom_providers = [
        {
          name = "coding";
          base_url = "http://skrye.drongo-gamma.ts.net:8080/v1";
        }
        {
          name = "agentic";
          base_url = "http://zannah.drongo-gamma.ts.net:8080/v1";
        }
        {
          name = "revan";
          base_url = "http://revan.drongo-gamma.ts.net:8080/v1";
        }
      ];

      # Smart routing: trivial messages → small local model
      smart_model_routing = {
        enabled = true;
        max_simple_chars = 160;
        max_simple_words = 28;
        cheap_model = {
          base_url = "http://revan.drongo-gamma.ts.net:8080/v1";
          model = "gemma4-e4b";
        };
      };

      # Fallback to cloud on local inference failure
      fallback_model = {
        provider = "anthropic";
        model = "claude-sonnet-4-6";
      };

      # Subagent delegation → coding model
      delegation = {
        base_url = "http://skrye.drongo-gamma.ts.net:8080/v1";
        model = "qwen3-coder-30b-a3b";
      };

      # Auxiliary models for side tasks (vision, web, compression)
      auxiliary = {
        vision = {
          base_url = "http://revan.drongo-gamma.ts.net:8080/v1";
          model = "gemma4-e4b";
          timeout = 180;
        };
        web_extract = {
          base_url = "http://revan.drongo-gamma.ts.net:8080/v1";
          model = "gemma4-e4b";
          timeout = 360;
        };
        compression = {
          base_url = "http://zannah.drongo-gamma.ts.net:8080/v1";
          model = "qwen3.5-9b";
          timeout = 180;
        };
      };

      # Memory: built-in + Holographic (local SQLite)
      memory = {
        memory_enabled = true;
        user_profile_enabled = true;
        provider = "holographic";
      };

      # Smart approvals for terminal commands
      approvals.mode = "smart";

      # Terminal backend (inside the container)
      terminal = {
        backend = "local";
        timeout = 120;
      };

      # Timezone
      timezone = "Europe/London";

      # Streaming to Telegram
      streaming = {
        enabled = true;
        transport = "edit";
        edit_interval = 0.5;
      };
    };

    # --- MCP servers ---
    mcpServers = {
      exa = {
        url = "https://mcp.exa.ai/mcp";
      };
      jina = {
        url = "https://mcp.jina.ai/v1";
        headers.Authorization = "Bearer \${JINA_API_KEY}";
      };
      context7 = {
        url = "https://mcp.context7.com/mcp";
        headers.Authorization = "Bearer \${CONTEXT7_API_KEY}";
      };
      cloudflare = {
        url = "https://docs.mcp.cloudflare.com/mcp";
      };
      nixos = {
        command = "mcp-nixos";
      };
    };
  };

  # Passwordless podman for CLI routing into container
  security.sudo.extraRules = [{
    users = [ "martin" ];
    commands = [{
      command = "/run/current-system/sw/bin/podman";
      options = [ "NOPASSWD" ];
    }];
  }];

  # sops-nix secret containing API keys and tokens
  sops.secrets."hermes-env" = {
    sopsFile = ./secrets/ai.yaml;
    format = "yaml";
  };
}
```

The sops-encrypted secrets file contains:

```yaml
hermes-env: |
    TELEGRAM_BOT_TOKEN=123456:ABC...
    ANTHROPIC_API_KEY=sk-ant-...
    JINA_API_KEY=jina_...
    CONTEXT7_API_KEY=c7_...
```

MCP server environment variables in `headers` use `${VAR}` syntax, resolved from the `.env` file at runtime.

**Streaming timeouts**: Hermes auto-adjusts timeouts for local providers (localhost, LAN IPs). Tailscale addresses (100.x.y.z) may not be auto-detected as local. If prefill latency on large models causes timeouts, set `HERMES_STREAM_READ_TIMEOUT=1800` in the environment.

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

**Decision**: Five local model roles plus two external fallback tiers. Smart routing handles simple vs complex automatically. Manual `/model` switching selects the appropriate named provider for specific tasks. Delegation routes subagent coding work. Auxiliary routing handles vision, compression, and web extraction.

| Role / tier | Where | Models | Routing mechanism |
|---|---|---|---|
| **Embedding** | Revan or any inference host with enough VRAM | qwen3-embedding:4b-q8_0, qwen3-embedding:0.6b-q8_0 | Future use (Honcho, OpenViking); not required for Holographic memory |
| **Coding** | Strix Halo 1 (Skrye) | qwen3-coder-next, qwen3-coder:30b-a3b, qwen2.5-coder:14b, qwen2.5-coder:7b | `/model custom:coding:<model>` or automatic via delegation |
| **Agentic** | Strix Halo 2 (Zannah) | qwen3.5:35b-a3b, qwen3.5:9b, rnj-1:8b | Default model; smart routing keeps complex messages here |
| **Reasoning** | Strix Halo 2 (Zannah) | gemma4:26b, gpt-oss:20b, qwen3.5:9b | `/model custom:agentic:gemma4-26b` |
| **Small / media** | Revan | gemma4:e4b, gemma4:e2b | Smart routing sends simple messages here; auxiliary vision/web extraction route here automatically |
| **Cloud fallback** | Anthropic | claude-sonnet-4-6 | Automatic on local inference failure; or `/model anthropic` for manual escalation |
| **Frontier** | Anthropic | claude-opus-4-6 | `/model anthropic` with explicit model name for deep research |

The exact local model bound to each role is selected from `nixos/_mixins/server/llama-server/model-policy.nix` by VRAM tier. The `fallback_model` setting handles automatic failover to cloud. Manual `/model` switching covers task-specific needs until capability-based routing (Hermes issue #157) matures.

**Generation policy**: sampler settings are now documented in the shared llama policy beside each role entry, not hard-coded in per-host `llama-server` commands. The current rule is:

- Copy Unsloth's published local-run defaults when there is a primary-source Unsloth page for that exact model family.
- Store those values per role entry, because the same family can need different settings for `coding`, `agentic`, and `reasoning`.
- Leave the generation block unset when there is no primary-source local-run guidance for the chosen model.
- Do not attach generation settings to embedding models.

That yields the current split:

- `Qwen3-Coder-Next`, `Qwen3-Coder-30B-A3B`, `Qwen3.5`, `Gemma 4`, and `gpt-oss` use source-backed Unsloth sampler values.
- `Qwen2.5-Coder-14B`, `Qwen2.5-Coder-7B`, and `rnj-1` currently keep sampler settings unset in policy.
- `Qwen3-Embedding-4B` and `Qwen3-Embedding-0.6B` omit generation settings entirely.

The rationale is operational, not aesthetic. These settings are part of the model contract in the same way context window and KV cache type are. Keeping them in the shared policy makes the serving layer deterministic and keeps future routing work aligned with the model family guidance that produced the settings in the first place.

### 4. Workspace Files: Nix-Declared

**Decision**: Agent identity files (`SOUL.md`, `USER.md`) are declared via the Hermes NixOS module's `documents` option, not manually created or synced.

**Rationale**: Version-controlled, reproducible, no drift. Documents are installed into the agent's working directory on every `nixos-rebuild switch`. Managed mode prevents the agent or manual edits from altering the Nix-declared files.

**Implementation**:

```nix
services.hermes-agent.documents = {
  "SOUL.md" = builtins.readFile ./traya-soul.md;
  "USER.md" = builtins.readFile ./traya-user.md;
};
```

Hermes reads `SOUL.md` as the agent's primary identity (slot #1 in the system prompt). `USER.md` provides user context. Both are injected at session start alongside the built-in memory.

### 5. Messaging Interface: Telegram

**Decision**: Telegram is the sole human-agent interface. See [TELEGRAM-vs-DISCORD.md](TELEGRAM-vs-DISCORD.md) for the full evaluation.

Webhook-based integrations from external services (GitHub, Grafana, uptime monitors) will use a lightweight HTTP-to-Telegram bridge when needed. The bridge receives HTTP POSTs from external services and relays them to the appropriate Telegram topic via `sendMessage`.

**Implementation**:
- BotFather token for `@TrayaSithbot`
- Long polling only - no webhook, no public endpoint; works behind NAT
- Bot token stored in sops-encrypted `environmentFiles` (as `TELEGRAM_BOT_TOKEN`)
- Forum-enabled supergroup for shared context; per-topic session isolation
- Hermes Telegram gateway supports slash commands, streaming via progressive message editing, voice memo transcription, and link preview control

### 6. MCP Tools

**Decision**: MCP servers are declared via the Hermes NixOS module's `mcpServers` option. Server definitions are the source of truth in `configuration.nix`. The same servers used for Home Manager development tools will be available to the agent.

**Rationale**: Hermes has native MCP support (stdio and HTTP transports). The `mcpServers` NixOS option renders directly into `config.yaml` with no manual wiring. Environment variables in `headers` and `env` values resolve from the sops-injected `.env` file at runtime.

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

Most servers are remote HTTP; only `nixos` runs as a local binary (`pkgs.mcp-nixos`). Node.js is not required for any of them. Secrets (Jina API key, Context7 API key) are in `secrets/ai.yaml` and injected via sops into the Hermes environment.

See the Hermes NixOS configuration in §2 for the full `mcpServers` declaration.

### 7. GitHub Access

**Decision**: Traya holds scoped PATs for the owner's personal projects (contributions via pull requests or carefully constrained actions) and full permissions inside the `the-cauldron` org (create, fork, experiment freely). GitHub integration is deferred until the GitHub tooling phase.

**Research required - GitHub MCP vs `gh` CLI**:

| Option | Notes |
|---|---|
| [github/github-mcp-server](https://github.com/github/github-mcp-server) | Official MCP server; HTTP transport; fine-grained PAT; structured tool calls for issues, PRs, code. Hermes `mcpServers` option supports this directly. |
| `gh` CLI | Already Nix-packaged; scriptable; agents can invoke it via exec tool; no MCP overhead |

GitHub MCP is cleaner for agents that interact with GitHub as a structured API. `gh` is simpler to provision (add to `extraPackages` in native mode, or install in the container). Decision pending.

**When implemented** (regardless of method):
- Fine-grained PAT for `sith-traya`, scoped to specific personal repositories
- Permissions: issues read/write, PRs read/write, contents read
- Full permissions within the `the-cauldron` org
- Token stored in sops-encrypted `environmentFiles`
- Start read-only, upgrade to write in a later phase

### 8. Security Posture

**Decision**: Graduated capability rollout. Start locked down, enable tools incrementally.

**Guiding principle**: OpenClaw's security track record (multiple CVEs in weeks, ClawJacked attack, malicious skills in marketplace, log poisoning, exposed instances) informs this posture. Hermes is pre-v1.0 and moving fast (v0.2 to v0.9 in two months). The podman container boundary is the primary safety layer - exec and cron are enabled, but they operate within an isolated container with no host-level privilege.

**Hardening measures**:

| Control | Setting | Notes |
|---|---|---|
| Container isolation | Podman (via Hermes NixOS module) | Process, filesystem, network isolation; primary safety layer |
| Network | `--network=host` | Container shares host network for Tailscale access; gateway binds localhost only |
| Managed mode | Automatic (NixOS module) | Blocks CLI config mutation; all config via `nixos-rebuild switch` |
| Smart approvals | `approvals.mode = "smart"` | LLM classifies command risk; low-risk auto-approved, high-risk escalated |
| Messaging allowlist | Martin's user ID only (DM pairing) | Hermes default: unknown senders get a pairing code, not processed |
| Secret management | sops-nix `environmentFiles` | API keys and tokens in encrypted secrets, injected into `.env` at activation |
| Secret redaction | Built-in | Hermes auto-redacts API key patterns in tool output and logs |
| Memory security | Built-in | Memory entries scanned for injection/exfiltration patterns before acceptance |
| Skills trust | Bundled + official only initially | ClawHub and community skills not installed until reviewed |
| Exec tool | **Enabled** | Scoped to container filesystem only |
| Cron tool | **Enabled** | Scheduled tasks with platform delivery |
| Tailscale mesh | WireGuard encryption | All inter-host inference traffic encrypted in transit |

**Phased rollout**:

| Phase | Scope | Tools Enabled |
|---|---|---|
| 1 | Research: choose agent software and messaging platform | - |
| 2 | Deploy Revan hub: llama-swap, RTX 2000e, embedding, small model | - |
| 3 | Deploy Strix Halo inference: llama-swap on both hosts, Tailscale mesh | - |
| 4 | Hermes on Revan: NixOS module, podman, Telegram, model config, Holographic memory | Chat, exec, cron |
| 5 | Add MCP servers (context7, exa, jina, nixos) | Search, read web pages, docs |
| 6 | Add GitHub tooling (read-only PAT) | Review PRs, read issues |
| 7 | Upgrade PAT to write | Comment on PRs, propose fixes |
| 8 | Add workspace file tools + scheduled tasks | Scheduled reviews, blog post drafts |

### 9. Memory Architecture

**Decision**: Start with Hermes built-in memory plus Holographic (local SQLite). Graduate to Honcho when operational experience warrants it.

**Three memory layers (day one)**:

| Layer | What | Storage | Token cost |
|---|---|---|---|
| **Built-in memory** | MEMORY.md (~800 tokens) and USER.md (~500 tokens) injected into every system prompt. Agent proactively stores preferences, corrections, environment facts. | `~/.hermes/memories/` (markdown files) | Fixed ~1,300 tokens per session |
| **Session search** | FTS5 full-text search across all past conversations in SQLite. Agent can search with `session_search` tool. | `~/.hermes/state.db` | On-demand (LLM summarisation of results) |
| **Holographic** | Local SQLite fact store with FTS5 search, trust scoring, contradiction detection, and HRR algebraic queries. Zero external dependencies. | `$HERMES_HOME/memory_store.db` | On-demand (searched when relevant) |

Holographic adds trust-scored facts that the agent can store, search, and reason about across sessions. The `fact_feedback` tool lets the agent (or user, via conversation) rate retrieved facts as helpful or unhelpful, adjusting trust scores over time. Contradictions between facts are automatically detected. No embedding model, no external API, no additional services.

**Embedding models are not required for day one.** Built-in memory is text injection, session search is FTS5, and Holographic uses HRR algebra, not vector embeddings. The embedding models on Revan (qwen3-embedding) become relevant when upgrading to a vector-search memory provider (OpenViking, Honcho).

**Future: Honcho (dialectic user modelling)**:

Honcho is the most sophisticated memory provider available - it reasons about who you are using multi-pass LLM analysis, building representations that deepen over time. It requires PostgreSQL + pgvector, a FastAPI server, a background deriver worker, and LLM API keys for the reasoning pipeline. The hosted service offers $100 free credits on sign-up with usage-based pricing ($2/M tokens ingestion, unlimited retrieval, $0.001-$0.50/query for reasoning).

Graduate to Honcho when:
1. Operational experience with Hermes establishes how memory actually affects agent behaviour
2. The limits of Holographic's fact-store approach are felt in practice
3. The infrastructure cost (PostgreSQL + deriver + LLM API calls) is justified by the improvement

## Nix Packaging

The Hermes Agent flake provides the NixOS module, packages, and dev shell. The flake input replaces the previously planned `llm-agents.nix` for the agent binary. llama-swap v201 remains packaged as a local Nix derivation.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    hermes-agent.url = "github:NousResearch/hermes-agent";
  };

  outputs = { nixpkgs, hermes-agent, ... }: {
    nixosConfigurations.revan = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        hermes-agent.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
```

Pin the Hermes flake input to a specific commit rather than tracking `main` - the project ships features rapidly (v0.2 to v0.9 in two months) and breaking changes between versions are expected.

## What Is Not In Scope

- **Syncthing**: Nix handles shared configuration. Revan backup/recovery is a separate concern, mechanism TBD.
- **Discord**: Evaluated and set aside. Telegram covers all interaction needs; webhook integrations will use a lightweight bridge service rather than maintaining a second chat platform.
- **Agent-to-agent (A2A) protocol**: Skrye and Zannah are reserved for future activation. Multi-agent capabilities in Hermes (delegation, subagents) are worth monitoring for future subordinate agent work.
- **systemd-nspawn containers**: Originally planned for ZeroClaw isolation. Replaced by the Hermes NixOS module's podman container mode, which provides equivalent isolation with less custom wiring.
- **Docker**: Hermes module supports Docker as a container backend but podman is preferred (already in the NixOS config, rootless-capable, no daemon).
- **ClawHub / community skills marketplace**: Not evaluated for security. Install skills from bundled and official sources only until trust model is established.
- **Agent role definitions**: Martin will determine specific agent roles and scheduled tasks during deployment.
- **Master/padawan topology**: Superseded by the Revan hub architecture. Both Strix Halos are now dedicated inference nodes rather than one sitting idle as a warm standby. If Revan goes down, Hermes can be deployed to either Strix Halo as a degraded-mode fallback using the same NixOS module.
- **Ollama**: Transitional. llama-server via llama-swap is the production inference backend on all hosts. Ollama may remain installed for ad-hoc model downloads but is not in the production path.
- **Honcho (day one)**: Honcho is the target memory provider for future use. Day-one deployment uses Holographic (local SQLite, zero dependencies). See §9 Memory Architecture.
- **Capability-based model routing**: Hermes issue #157 proposes automatic routing based on task capability categories. Not yet implemented. Manual `/model` switching plus smart routing covers current needs.

## Future Expansion

Skrye and Zannah are reserved for future activation as subordinate agents, potentially cloud-based, commanded by Traya. The hierarchy mirrors the Sith Triumvirate from which they draw their names. No deployment work is planned for either until Traya's Revan hub setup is stable.

**Revan GPU headroom**: the RTX 2000e's 16 GB VRAM is lightly utilised (~7 GB for embedding + small model + Jellyfin). Future options include: a larger local model for more capable on-hub inference, a re-ranking model (qwen3-reranker:4b) for improved retrieval quality, or additional embedding models for specialised domains.

**NPU co-processing**: the Strix Halo NPU (40 XDNA2 units) is not yet usable with llama.cpp. Once tooling matures, it could run embedding or small models concurrently with the iGPU, increasing per-host capacity. See [OLLAMA-vs-LLAMACPP.md](OLLAMA-vs-LLAMACPP.md) §10.

**Honcho memory provider**: Graduate from Holographic to Honcho when operational experience justifies the infrastructure. Options: self-host (PostgreSQL + pgvector + FastAPI + deriver), or use the hosted service ($100 free credits, usage-based pricing thereafter). See §9 Memory Architecture.

**Capability-based routing**: Hermes issue #157 proposes user-configurable model routing by capability category (speed, reasoning, coding, cost). When this lands, it would replace manual `/model` switching for most task-type routing. Monitor the issue.

**Skills that declare models**: Currently not supported in Hermes. Skills are knowledge documents, not execution units with their own model preferences. If per-skill model declaration lands, it would allow coding skills to automatically route to the coding endpoint.

## Key References

| Resource | URL |
|---|---|
| Hermes Agent GitHub | https://github.com/NousResearch/hermes-agent |
| Hermes Agent docs | https://hermes-agent.nousresearch.com/docs/ |
| Hermes NixOS setup guide | https://hermes-agent.nousresearch.com/docs/getting-started/nix-setup |
| Hermes AI providers | https://hermes-agent.nousresearch.com/docs/integrations/providers |
| Hermes memory system | https://hermes-agent.nousresearch.com/docs/user-guide/features/memory |
| Hermes memory providers | https://hermes-agent.nousresearch.com/docs/user-guide/features/memory-providers |
| Hermes configuration | https://hermes-agent.nousresearch.com/docs/user-guide/configuration |
| Honcho GitHub | https://github.com/plastic-labs/honcho |
| Honcho docs | https://docs.honcho.dev/ |
| Honcho pricing | https://honcho.dev/#pricing |
| PicoClaw vs ZeroClaw evaluation (historical) | [PICO-vs-ZERO.md](PICO-vs-ZERO.md) |
| llama-swap (v201) | https://github.com/mostlygeek/llama-swap |
| llama-swap configuration docs | https://github.com/mostlygeek/llama-swap/blob/main/docs/configuration.md |
| PNY RTX 2000e Ada Generation | https://www.pny.com/rtx-2000e-ada-generation |
| Framework Desktop ML Benchmarks | https://frame.work/nl/en/desktop?tab=machine-learning |
| AMD ROCm for Radeon/Ryzen | https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/ |
| Tailscale performance best practices | https://tailscale.com/docs/reference/best-practices/performance |
| Telegram vs Discord evaluation | [TELEGRAM-vs-DISCORD.md](TELEGRAM-vs-DISCORD.md) |
| Backend comparison and model selection | [OLLAMA-vs-LLAMACPP.md](OLLAMA-vs-LLAMACPP.md) |
