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

## Key Decisions

The core platform choices are settled:

| Question | Decision | Notes |
|---|---|---|
| Agent software | **Hermes Agent** | Chosen because it has a first-class NixOS module, declarative configuration, native and container deployment modes, durable memory primitives, and active upstream development. |
| Messaging platform | **Telegram** | Chosen because it fits the primary mobile chat workflow, works behind NAT with long polling, handles voice notes well, and avoids running a public webhook endpoint. |
| Inference architecture | **Revan hub + Strix Halo inference** - decided. See [llama-server README](../llama-server/README.md) | llama-swap on all hosts; Tailscale mesh; RTX 2000e for embedding |
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

Hermes Agent and Telegram are the settled foundation for the deployment. See [llama-server README](../llama-server/README.md) for the performance case, hardware benchmarks, backend comparison, and model-serving rationale.

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

1. **Smart routing** (automatic): Simple and short messages stay on the cheap local model on Revan. Complex messages can be switched manually to a larger remote agentic model. This is a lightweight split based on message length and complexity heuristics, not task classification.
2. **Manual switching**: `/model custom:coding:qwen3-coder-30b-a3b` switches to the coding endpoint mid-session. `/model custom:agentic:qwen3.5-35b-a3b` switches to the larger remote agentic model when needed. `/model anthropic` escalates to cloud.
3. **Delegation**: Subagent tasks (spawned via `delegate_task`) automatically route to a different model/provider, configured globally. Coding subtasks go to the coding endpoint.
4. **Auxiliary models**: Side tasks (vision, web extraction, compression, approvals) each route to a configured endpoint, separate from the main conversation model. These fire automatically.
5. **Fallback**: If the primary model fails, errors, or hits rate limits, Hermes auto-switches to the configured fallback provider (`openai-codex`). Fires once per session.

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
    };

    # --- Model and provider configuration ---
    settings = {
      # Initial default: cheap local model on Revan
      model = {
        default = "qwen3.5:9b";
        provider = "custom";
        base_url = "http://revan.drongo-gamma.ts.net:8080/v1";
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

      # Smart routing: trivial messages stay on the same local endpoint
      smart_model_routing = {
        enabled = true;
        max_simple_chars = 160;
        max_simple_words = 28;
        cheap_model = {
          base_url = "http://revan.drongo-gamma.ts.net:8080/v1";
          model = "qwen3.5:9b";
        };
      };

      # Fallback to ChatGPT Pro subscription on local inference failure
      fallback_model = {
        provider = "openai-codex";
        model = "gpt-5.4";
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

  sops.secrets = {
    TELEGRAM_BOT_TOKEN.sopsFile = ./secrets/hermes.yaml;
    OPENAI_API_KEY.sopsFile = ./secrets/ai.yaml;
    CONTEXT7_API_KEY.sopsFile = ./secrets/mcp.yaml;
    JINA_API_KEY.sopsFile = ./secrets/mcp.yaml;
  };

  sops.templates."hermes-env" = {
    content = ''
      TELEGRAM_BOT_TOKEN=${config.sops.placeholder.TELEGRAM_BOT_TOKEN}
      OPENAI_API_KEY=${config.sops.placeholder.OPENAI_API_KEY}
      CONTEXT7_API_KEY=${config.sops.placeholder.CONTEXT7_API_KEY}
      JINA_API_KEY=${config.sops.placeholder.JINA_API_KEY}
    '';
  };
}
```

The rendered runtime `.env` contains:

```dotenv
TELEGRAM_BOT_TOKEN=123456:ABC...
OPENAI_API_KEY=sk-proj-...
JINA_API_KEY=jina_...
CONTEXT7_API_KEY=c7_...
```

MCP server environment variables in `headers` use `${VAR}` syntax, resolved from the `.env` file at runtime.

**Streaming timeouts**: Hermes auto-adjusts timeouts for local providers (localhost, LAN IPs). Tailscale addresses (100.x.y.z) may not be auto-detected as local. If prefill latency on large models causes timeouts, set `HERMES_STREAM_READ_TIMEOUT=1800` in the environment.

See [llama-server README](../llama-server/README.md) §9 for the full llama-swap configurations, model distribution per host, and rationale per model slot.

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

**Decision**: Declare `SOUL.md` via the Hermes NixOS module's `documents` option. Leave `USER.md` to Hermes' built-in memory system.

**Rationale**: `SOUL.md` is durable agent identity, so it belongs in version-controlled Nix config. Hermes treats `USER.md` as mutable user-profile memory under `~/.hermes/memories/USER.md`, maintained by the memory system. Documents are installed into the agent's working directory on every `nixos-rebuild switch`. Managed mode prevents the agent or manual edits from altering the Nix-declared identity file.

**Implementation**:

```nix
services.hermes-agent.documents = {
  "SOUL.md" = builtins.readFile ./traya-soul.md;
};
```

Hermes reads `SOUL.md` as the agent's primary identity, slot #1 in the system prompt. `USER.md` lives in the Hermes memory store and captures user preferences, communication style, and workflow habits over time.

### 5. Messaging Interface: Telegram

**Decision**: Telegram is the sole human-agent interface.

**Rationale**: Telegram matches the intended day-to-day workflow better than Discord. It supports direct mobile-first interaction, long polling without exposing a public endpoint, and practical voice-note handling. Discord's remaining advantage is inbound webhook convenience, and that gap is small enough to cover with a lightweight bridge when external systems need to notify the agent.

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

Most servers are remote HTTP; only `nixos` runs as a local binary (`pkgs.mcp-nixos`). Node.js is not required for any of them. Secrets for Jina and Context7 live in `secrets/mcp.yaml` and are injected into the Hermes environment through the rendered `hermes-env` file.

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

I hit the context ceiling on the Wolfi repo (it has 3,500+ package files). But I have everything I need from the wolfi-base image docs, the Nix dockerTools documentation, and the entrypoint source code. Wolfi packages follow the same names as Alpine/standard Linux: `bash`, `coreutils`, `util-linux`, `shadow`, `nodejs`, `git`, `curl` - they're all in the `wolfi-dev/os` repo.

Here's the new section:

---

### 10. Hermes Container Image Strategy

**Decision**: Start with the default Ubuntu 24.04 base image. Evaluate and implement a pre-seeded custom image as a future improvement, published to `ghcr.io/the-cauldron/hermes-base`.

**How container provisioning works**: The Hermes NixOS module's container mode pulls a base OCI image at runtime, creates a podman container with bind mounts (`/nix/store` read-only, `/var/lib/hermes` read-write, `/home/hermes` read-write), and runs a Nix-built entrypoint script inside the container on every start. The entrypoint provisions the `hermes` user (if not already present), optionally installs system packages via apt (Ubuntu/Debian only), sets up `uv` and a Python 3.11 venv, configures sudo, and drops privileges before executing the Hermes binary. The Hermes binary itself runs from the bind-mounted `/nix/store`, not from the container's filesystem.

Every provisioning block in the entrypoint has independent guards (sentinel files, `command -v` checks, existing-user lookups) and graceful fallbacks. The entrypoint explicitly supports arbitrary base images including Debian, Alpine, and glibc-based distros like Wolfi.

The persistent home directory (`/home/hermes`) survives container recreation. The agent can `pip install`, `uv tool install`, and `npm install -g` into the home directory at any time. These installs persist across restarts, rebuilds, and even image changes.

**Four approaches evaluated**, from simplest to most controlled:

#### Option A: Bare Ubuntu 24.04 (default, recommended to start)

No custom image needed. The Hermes NixOS module default.

```nix
services.hermes-agent.container.image = "ubuntu:24.04";
```

On first boot, the entrypoint provisions `sudo`, `nodejs`, `npm`, `curl` via apt, installs `uv` via curl, and creates a Python 3.11 venv. A sentinel file (`/var/lib/hermes-tools-provisioned`) prevents re-provisioning on subsequent starts. The writable layer persists across restarts but is lost on container recreation (image/volume/options change).

**Trade-offs**: First boot takes 30-60 seconds for apt/uv provisioning. Writable layer loss on recreation means re-running apt. No CVE scanning of the base layer. Ubuntu's security posture is adequate but not hardened.

#### Option B: Pre-seeded Ubuntu 24.04 (published to ghcr.io)

A Containerfile that bakes in the tools the entrypoint would otherwise install on first boot. Eliminates first-boot provisioning and writable-layer dependency.

```dockerfile
# Containerfile.ubuntu
FROM ubuntu:24.04

# Pre-install what the entrypoint would provision on first boot
RUN apt-get update -qq && \
    apt-get install -y -qq --no-install-recommends \
      sudo nodejs npm curl git jq ripgrep && \
    rm -rf /var/lib/apt/lists/*

# Touch the sentinel so the entrypoint skips apt provisioning
RUN touch /var/lib/hermes-tools-provisioned

# Sudoers will be configured by the entrypoint based on HERMES_UID
```

```nix
services.hermes-agent.container.image = "ghcr.io/the-cauldron/hermes-base:ubuntu";
```

Built via GitHub Actions, pushed to ghcr.io. The entrypoint still handles user creation and privilege drop, it just skips the apt block.

#### Option C: Pre-seeded Wolfi (published to ghcr.io)

A Wolfi-based image using `cgr.dev/chainguard/wolfi-base`. Wolfi is glibc-based (unlike Alpine's musl), so the Nix-built Hermes binary has no linker issues. The entrypoint's apt block is skipped entirely (no `apt-get` in Wolfi). User creation falls through to the `adduser`/`addgroup` path (busybox-style, present in wolfi-base).

```dockerfile
# Containerfile.wolfi
FROM cgr.dev/chainguard/wolfi-base

# Install agent tools via apk
RUN apk update && apk add --no-cache \
      bash coreutils util-linux shadow \
      nodejs npm git curl jq ripgrep

# Touch the sentinel to skip any residual apt checks
RUN touch /var/lib/hermes-tools-provisioned
```

```nix
services.hermes-agent.container.image = "ghcr.io/the-cauldron/hermes-base:wolfi";
```

**Trade-offs**: Low-to-zero CVE base image (Chainguard's daily rebuild cadence). glibc-based, so Nix store binaries work without issues. No system package manager abuse possible (no apt, and apk is not what the entrypoint looks for). Agent can still `pip install` and `npm install -g` into the persistent home directory.

#### Option D: Nix-composed OCI image (published to ghcr.io)

A fully reproducible image built with `pkgs.dockerTools.buildLayeredImage`. Every byte in the image is declared in Nix. No package manager, no first-boot provisioning, no network calls. The entrypoint's provisioning blocks all become no-ops because the tools and user already exist.

```nix
# nix/hermes-container-image.nix
{ pkgs }:
pkgs.dockerTools.buildLayeredImage {
  name = "ghcr.io/the-cauldron/hermes-base";
  tag = "nix";

  contents = with pkgs; [
    bashInteractive
    coreutils
    gnugrep
    gnused
    findutils
    util-linux   # provides setpriv
    shadow       # provides useradd/groupadd
    git
    curl
    jq
    ripgrep
    nodejs
    cacert       # TLS certificates
  ];

  fakeRootCommands = ''
    # Create the hermes tools sentinel
    mkdir -p ./var/lib
    touch ./var/lib/hermes-tools-provisioned

    # Create the home directory mount point
    mkdir -p ./home/hermes
  '';

  enableFakechroot = true;

  config = {
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "PATH=/usr/bin:/bin:/usr/local/bin"
    ];
    Cmd = [ "${pkgs.bashInteractive}/bin/bash" ];
  };
}
```

Build and push via CI:

```bash
nix build .#hermes-container-image
podman load < result
podman push ghcr.io/the-cauldron/hermes-base:nix
```

```nix
services.hermes-agent.container.image = "ghcr.io/the-cauldron/hermes-base:nix";
```

**Trade-offs**: Maximum reproducibility and control. No system package manager at all, the agent can only use baked-in tools plus home-directory installs (pip, uv, npm). The `fakeRootCommands` approach handles user pre-creation and sentinel files. The image requires `shadow` (for `useradd`/`groupadd`) so the entrypoint's user-creation path has tools available if the UID doesn't match a pre-created user.

⚠️ **CAVEAT for Nix images**: `dockerTools.buildLayeredImage` does not create `/etc/passwd` or `/etc/group` by default. Include `pkgs.fakeNss` in `contents` for basic entries (root, nobody), or use `fakeRootCommands` with `shadowSetup` + `useradd` to pre-create the hermes user. Without this, the entrypoint's `getent passwd` call won't find any users, triggering the user-creation path which needs `useradd` from `shadow`.

#### Recommended Path

Start with **Option A** (bare Ubuntu). It works out of the box with zero custom image work. Once the deployment is stable and the agent's tool requirements are understood from real usage, build a pre-seeded image (Option B, C, or D) and switch `container.image`. The self-improvement cycle then becomes:

1. Agent discovers it needs a tool, installs it via `pip`/`npm` into the persistent home dir
2. Over time, frequently-used tools are candidates for baking into the base image
3. Traya (with GitHub write access) proposes a PR to the container repo adding the tool
4. Martin reviews and merges; GitHub Actions builds and pushes the new image
5. `nixos-rebuild switch` picks up the new image tag, container is recreated with tools pre-installed

The choice between Option B (Ubuntu), C (Wolfi), and D (Nix) is a decision for after operational experience. Wolfi is the natural fit given Martin's Chainguard background and offers the best CVE posture. The Nix-composed image offers maximum reproducibility at the cost of no in-container package manager. Both are viable and the entrypoint handles either gracefully.



Here are the two new sections:

---

### 11. Databases

Hermes stores all persistent state in `$HERMES_HOME` (`/var/lib/hermes/.hermes/` on the host). This directory is bind-mounted into the podman container at `/data/.hermes` (read-write) and persists across container recreation, image changes, and host reboots. No external database services are required.

**Database files:**

| File | Type | Purpose | Created |
|---|---|---|---|
| `state.db` | SQLite (WAL mode) | CLI and messaging sessions, FTS5 full-text search index, gateway state | Always |
| `memory_store.db` | SQLite | Holographic memory provider: fact store, trust scores, HRR algebraic data | When `memory.provider = "holographic"` |
| `memories/MEMORY.md` | Markdown | Agent's persistent notes (environment facts, conventions, lessons learned) | Always |
| `memories/USER.md` | Markdown | User profile (preferences, communication style, role) | Always |
| `auth.json` | JSON | OAuth credentials (Telegram, provider tokens) | When OAuth is configured |
| `mcp-tokens/` | Directory | OAuth tokens for MCP servers | When MCP OAuth is used |

Additionally, `sessions/` may contain per-session data files alongside what is indexed in `state.db`. The `skills/` directory holds agent-created and hub-installed skills. The `cron/` directory holds scheduled task definitions.

All databases are SQLite. No PostgreSQL, Redis, or other external database services are needed unless a future memory provider upgrade (Honcho, Hindsight local mode) introduces one. That is not in scope for the initial deployment.

**SQLite WAL mode note**: Hermes uses SQLite in WAL (Write-Ahead Logging) mode for `state.db`. WAL mode means the database consists of three files: `state.db`, `state.db-wal`, and `state.db-shm`. All three must be included in any backup. Copying only `state.db` while the WAL file has uncommitted transactions will produce an incomplete or corrupt backup.

### 12. Backup

**Decision**: Automated daily backups of Hermes state to an internal path on Revan. Simple, local, no external dependencies.

**Scope**: The backup captures the entire Hermes state directory (`/var/lib/hermes/`), which includes all databases, memories, sessions, skills, cron jobs, OAuth tokens, config, and workspace files.

**Strategy**: A systemd timer on Revan runs a daily backup that stops the Hermes service, creates a consistent snapshot, and restarts the service. The stop-snapshot-start approach avoids SQLite WAL consistency issues entirely. Given that Hermes is a personal agent with no SLA requirement, a brief daily interruption (typically under 10 seconds) is acceptable.

**Backup destination**: `/var/backup/hermes/` on Revan, with date-stamped snapshots and automatic retention.

**Implementation**:

```nix
# Hermes backup service and timer
systemd.services.hermes-backup = {
  description = "Backup Hermes Agent state";
  after = [ "hermes-agent.service" ];

  serviceConfig = {
    Type = "oneshot";
    ExecStart = pkgs.writeShellScript "hermes-backup" ''
      set -euo pipefail

      BACKUP_ROOT="/var/backup/hermes"
      STATE_DIR="/var/lib/hermes"
      DATE=$(date +%Y-%m-%d_%H%M%S)
      BACKUP_DIR="$BACKUP_ROOT/$DATE"
      RETAIN_DAYS=14

      mkdir -p "$BACKUP_ROOT"

      # Stop Hermes for a consistent snapshot
      systemctl stop hermes-agent.service || true

      # Snapshot the entire state directory
      ${pkgs.rsync}/bin/rsync -a --delete "$STATE_DIR/" "$BACKUP_DIR/"

      # Restart Hermes
      systemctl start hermes-agent.service

      # Prune backups older than retention period
      ${pkgs.findutils}/bin/find "$BACKUP_ROOT" -maxdepth 1 -type d -mtime +$RETAIN_DAYS -exec rm -rf {} +

      echo "Backup complete: $BACKUP_DIR ($(du -sh "$BACKUP_DIR" | cut -f1))"
    '';
  };
};

systemd.timers.hermes-backup = {
  description = "Daily Hermes Agent backup";
  wantedBy = [ "timers.target" ];
  timerConfig = {
    OnCalendar = "daily";
    Persistent = true;       # Run missed backups after downtime
    RandomizedDelaySec = 900; # Jitter to avoid exact midnight
  };
};
```

**What is backed up:**

| Path | Contents | Size estimate |
|---|---|---|
| `.hermes/state.db` + WAL/SHM | All sessions and gateway state | Grows with usage; typically 10-100 MB |
| `.hermes/memory_store.db` | Holographic facts (if enabled) | Small; < 10 MB for personal use |
| `.hermes/memories/` | MEMORY.md, USER.md | < 10 KB |
| `.hermes/config.yaml` | Generated config (Nix-managed, but backup captures runtime state) | < 10 KB |
| `.hermes/auth.json` | OAuth credentials | < 10 KB |
| `.hermes/skills/` | Agent-created and installed skills | Varies; typically < 1 MB |
| `.hermes/sessions/` | Per-session data files | Grows with usage |
| `.hermes/cron/` | Scheduled task definitions | < 100 KB |
| `home/` | Agent home dir (uv, pip, npm installs) | Varies; 100 MB - 1 GB depending on installed tools |
| `workspace/` | SOUL.md, agent-created files | Varies |

**Retention**: 14 daily snapshots kept by default. At an estimated 200 MB per snapshot for a moderately active personal agent, this uses approximately 3 GB of backup storage. Adjust `RETAIN_DAYS` based on actual usage.

**Monitoring**: Check backup health with:

```bash
# List backups
ls -la /var/backup/hermes/

# Check most recent backup
systemctl status hermes-backup.service
journalctl -u hermes-backup.service --since today

# Check timer schedule
systemctl list-timers hermes-backup.timer
```

**Recovery**: To restore from a backup:

```bash
# Stop Hermes
sudo systemctl stop hermes-agent.service

# Restore from a specific backup
sudo rsync -a --delete /var/backup/hermes/2026-04-15_030000/ /var/lib/hermes/

# Restart Hermes
sudo systemctl start hermes-agent.service
```

**What is not covered by this backup**: The llama-swap model files (`/var/lib/llama-models/`) are not included. Models are large (tens of GB), immutable, and re-downloadable via `llama-models-preseed.service`. Backing them up would waste storage for no benefit. The NixOS configuration itself is version-controlled in git and does not need file-level backup.

**Future consideration**: If Hermes state grows large enough that the stop-snapshot-start window becomes noticeable, switch to an online backup approach using `sqlite3 .backup` for each `.db` file while the service runs, followed by rsync of non-database files. For personal use at this scale, the simple approach is sufficient.

### 13. Coding Agents inside Hermes

**Decision**: Install Claude Code, Codex CLI, and Copilot CLI inside the Hermes podman container. Hermes orchestrates them via ACP (Agent Communication Protocol) for coding task delegation. Each coding agent runs as itself, fully in its own context, using its own subscription auth.

**Rationale**: Hermes handles routine agentic work (research, triage, memory, scheduled tasks) using self-hosted LLMs at zero marginal cost. When serious development work is needed, Hermes delegates to a coding agent that brings frontier model capability and a full development toolset. The coding agent runs autonomously inside the container - reading code, running tests, making edits - and returns the result to Hermes.

This is not Hermes using Claude's API key to make inference calls. Hermes spawns `claude` as a subprocess via ACP. Claude Code runs as Claude Code, with its own tools, its own auth, its own context window. Same for Codex and Copilot. Hermes is the orchestrator, not a proxy.

**Architecture:**

```
Telegram → Hermes (Revan, self-hosted LLMs via llama-swap)
               │
               ├── routine work → llama-swap (Qwen3.5, Gemma4) — zero cost
               │
               ├── coding delegation → claude via ACP — Claude Max subscription
               │     Claude Code runs autonomously inside the container
               │     reads code, runs tests, makes edits, returns result
               │
               ├── coding delegation → codex via ACP — ChatGPT Pro subscription
               │     Codex CLI runs autonomously inside the container
               │
               └── coding delegation → copilot --acp via ACP — Copilot Pro subscription
                      Copilot CLI runs autonomously inside the container
```

**Subscriptions:**

| Coding Agent | CLI Tool | Subscription | Status |
|---|---|---|---|
| Claude Code | `claude` | Claude Max (gifted by Anthropic) | Available |
| Codex CLI | `codex` | ChatGPT Pro (gifted by OpenAI) | Available |
| Copilot CLI | `copilot` | GitHub Copilot Pro | Available |

**Container isolation**: The coding agents run inside the Hermes podman container. They can execute terminal commands, read/write files, and make network calls, but only within the container boundary. They cannot touch the host filesystem, other services on Revan, or llama-swap processes. Hermes's smart approval system adds a second layer: dangerous commands still go through approval even inside the container.

This is a deliberate security design. Coding agents with autonomous tool use need a sandbox. The podman container provides it, with the Hermes approval system as a secondary gate. Permissions can be relaxed within the container without exposing the host.

**Installation**: The CLI tools are npm-installable into the persistent home directory. For the pre-seeded container image (§10), bake them into the base image:

```dockerfile
# Add to Containerfile
RUN npm install -g \
      @anthropic-ai/claude-code \
      @openai/codex \
      @githubnext/github-copilot-cli
```

**First-time auth setup**: Each coding agent needs a one-time interactive login. Credentials persist in the home directory (`/home/hermes/`) across container restarts and recreation.

```bash
# Interactive login via host CLI routing into container
podman exec -it hermes-agent claude login
podman exec -it hermes-agent codex login
podman exec -it hermes-agent copilot login
```

**How Hermes delegates**: The `copilot-acp` provider is confirmed working in Hermes. It spawns the Copilot CLI as a subprocess with `--acp --stdio`, sends a task, and receives structured results. The same ACP spawning mechanism should work for Claude Code and Codex CLI, pending verification of their ACP stdio support.

Hermes also has environment variables for customising the ACP command:

| Variable | Default | Purpose |
|---|---|---|
| `HERMES_COPILOT_ACP_COMMAND` | `copilot` | Override the Copilot CLI binary path |
| `HERMES_COPILOT_ACP_ARGS` | `--acp --stdio` | Override ACP arguments |

This suggests the ACP spawning mechanism is configurable, which may enable adapting it for `claude` and `codex` if they support a similar stdio protocol.

**Cost model**: Self-hosted LLMs handle 90%+ of interactions at zero API cost. Coding agent delegation is billed against existing subscriptions (Claude Max, ChatGPT Pro, Copilot Pro) which include generous usage allowances. The decision of when to delegate is made by Hermes based on task complexity or explicit user instruction (`/model` switching or natural language like "use Claude Code for this").

**Phased rollout**:

| Phase | Scope |
|---|---|
| Day one | Install CLI tools in the container, complete auth flows, verify `copilot-acp` works |
| Phase 2 | Test ACP delegation with Claude Code and Codex CLI, verify stdio protocol compatibility |
| Phase 3 | Configure Hermes delegation settings to route coding subtasks to preferred coding agent |
| Future | Traya proposes Containerfile PRs to bake in new tools or updated CLI versions |

**What needs verification**:

- Whether `claude` supports an ACP stdio mode that Hermes can spawn (similar to `copilot --acp --stdio`)
- Whether `codex` supports the same pattern
- Whether Hermes's ACP provider mechanism can be generalised beyond the `copilot-acp` provider to spawn arbitrary coding agents
- Whether the coding agents' own terminal tool use interacts correctly with Hermes's approval system inside the container

**What does not need verification**: The model provider path. Hermes already supports Anthropic (via Claude Code credentials) and OpenAI Codex (via OAuth) as inference providers. Even if ACP orchestration is not yet working for all three, the subscriptions can be used for direct model access from Hermes immediately.

### 14. Using Codex inside Hermes

**Decision**: Authenticate with OpenAI via the Hermes "Codex" provider to access GPT models directly through Martin's gifted ChatGPT Pro subscription. OAuth tokens managed declaratively via sops-nix.

**What this is**: The Hermes "Codex" provider is OpenAI subscription OAuth. It uses the same device code flow as the Codex CLI to authenticate against your ChatGPT subscription, then provides GPT-5.x, GPT-4o, and other models as a standard Hermes model provider. No Codex CLI installation required. No per-token API billing - usage is covered by the ChatGPT Pro subscription allowance.

**Why this matters**: With Codex OAuth as a provider, the fallback chain no longer needs a per-token Anthropic API key as the first cloud fallback. Subscription-based access to GPT models is available at zero marginal cost, making it the natural choice for cloud escalation when self-hosted models are insufficient.

**Updated fallback chain**:

```nix
settings = {
  # Primary: cheap self-hosted local model
  model = {
    default = "qwen3.5:9b";
    provider = "custom";
    base_url = "http://revan.drongo-gamma.ts.net:8080/v1";
  };

  # Fallback: GPT via ChatGPT Pro subscription (zero marginal cost)
  fallback_model = {
    provider = "openai-codex";
    model = "gpt-5.4";
  };
};
```

Per-token Anthropic API (`ANTHROPIC_API_KEY`) becomes a last-resort fallback, retained in `environmentFiles` but no longer the primary cloud escalation path.

**Full model access summary**:

| Provider | Subscription | Hermes provider name | Marginal cost |
|---|---|---|---|
| Self-hosted (llama-swap) | Hardware owned | `custom` (named providers: coding, agentic, revan) | Zero |
| OpenAI GPT | ChatGPT Pro (gifted) | `openai-codex` | Subscription included |
| Anthropic Claude | Claude Max (gifted) | `anthropic` | Subscription included |
| GitHub Copilot | Copilot Pro | `copilot` | Subscription included |
| Anthropic API | Pay-as-you-go | `anthropic` (with API key) | Per-token (last resort) |

**Declarative OAuth via sops-nix**:

The Hermes NixOS module has an `authFile` option that seeds OAuth credentials on first deployment. Combined with sops-nix, this makes the OAuth configuration fully declarative.

```nix
services.hermes-agent = {
  # OAuth credentials (Codex, Anthropic, etc.)
  authFile = config.sops.secrets."hermes/auth".path;

  # Non-OAuth secrets (API keys, bot tokens)
  environmentFiles = [ config.sops.secrets."hermes-env".path ];
};

sops.secrets."hermes/auth" = {
  sopsFile = ./secrets/hermes-auth.json;
  format = "json";
  owner = "root";
};

sops.templates."hermes-env" = {
  content = ''
    TELEGRAM_BOT_TOKEN=${config.sops.placeholder.TELEGRAM_BOT_TOKEN}
    OPENAI_API_KEY=${config.sops.placeholder.OPENAI_API_KEY}
    CONTEXT7_API_KEY=${config.sops.placeholder.CONTEXT7_API_KEY}
    JINA_API_KEY=${config.sops.placeholder.JINA_API_KEY}
  '';
};
```

**Secrets split**:

| Secret | Mechanism | Contents |
|---|---|---|
| `hermes.yaml` (sops, YAML) | secret input to `sops.templates."hermes-env"` | `TELEGRAM_BOT_TOKEN` |
| `ai.yaml` (sops, YAML) | secret input to `sops.templates."hermes-env"` | `OPENAI_API_KEY` |
| `mcp.yaml` (sops, YAML) | secret input to `sops.templates."hermes-env"` | `JINA_API_KEY`, `CONTEXT7_API_KEY` |
| `hermes/auth` (sops, JSON) | `authFile` | Codex OAuth token and other provider auth seeds |

Both are declared in `configuration.nix`, encrypted in the git repository, and injected by sops-nix at activation time.

**First-time setup (one-time, interactive)**:

The OAuth device code flow is inherently interactive - you approve access in a browser. This is the only imperative step.

```bash
# Start the container, then auth interactively
podman exec -it hermes-agent hermes model
# Select "OpenAI Codex"
# Browser opens: approve access with your ChatGPT Pro account
# Hermes stores the token in auth.json

# Optionally, also auth Anthropic
podman exec -it hermes-agent hermes model
# Select "Anthropic"
# Complete Claude Code auth flow

# Extract auth.json for sops encryption
sudo cat /var/lib/hermes/.hermes/auth.json > /tmp/auth.json
sops --encrypt /tmp/auth.json > secrets/hermes-auth.json
rm /tmp/auth.json

# Commit the encrypted secret
git add secrets/hermes-auth.json
```

After this, `nixos-rebuild switch` seeds the auth on any fresh deployment. The `authFile` is only copied if `auth.json` does not already exist (default behaviour), so it never clobbers refreshed tokens on a running system.

**Token lifecycle**:

- **Seeding**: `authFile` copies the sops-decrypted `auth.json` to `$HERMES_HOME/auth.json` on first activation
- **Refresh**: Hermes refreshes OAuth tokens automatically; refreshed tokens are written to the state directory and persist across rebuilds
- **Expiry**: If a refresh token expires (prolonged inactivity), re-do the device code flow interactively and update the sops secret
- **Disaster recovery**: The sops-encrypted auth seed in git is the recovery copy; re-deploy on any host and the tokens are injected

**Importing existing credentials**: If the Codex CLI is already authenticated on a local machine, Hermes can import credentials from `~/.codex/auth.json` automatically when present. Copy this file into the container's home directory or extract it for sops encryption as above.

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

**NPU co-processing**: the Strix Halo NPU (40 XDNA2 units) is not yet usable with llama.cpp. Once tooling matures, it could run embedding or small models concurrently with the iGPU, increasing per-host capacity. See [llama-server README](../llama-server/README.md) §10.

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
| llama-swap (v201) | https://github.com/mostlygeek/llama-swap |
| llama-swap configuration docs | https://github.com/mostlygeek/llama-swap/blob/main/docs/configuration.md |
| PNY RTX 2000e Ada Generation | https://www.pny.com/rtx-2000e-ada-generation |
| Framework Desktop ML Benchmarks | https://frame.work/nl/en/desktop?tab=machine-learning |
| AMD ROCm for Radeon/Ryzen | https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/ |
| Tailscale performance best practices | https://tailscale.com/docs/reference/best-practices/performance |
| Backend comparison and model selection | [llama-server README](../llama-server/README.md) |
