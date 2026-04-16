# PicoClaw vs ZeroClaw - Comparison for NixOS Agent Deployment

Last updated: 2026-04-16

> **⚠️ SUPERSEDED**: This document is retained as historical research. The decision to use ZeroClaw has been replaced by a decision to use **Hermes Agent** (NousResearch). See the reasoning below and the updated [README.md](README.md) for the current deployment plan.

## Decision: Hermes Agent

Research conducted on 2026-04-16 identified [Hermes Agent](https://github.com/NousResearch/hermes-agent) (by Nous Research, 90k stars, 445 contributors, Python, MIT licence) as a stronger fit than either PicoClaw or ZeroClaw for this deployment. The key factors:

**First-class NixOS module.** Hermes ships `nixosModules.default` in its upstream flake with declarative `settings` (rendered to `config.yaml`), `environmentFiles` (sops-nix compatible), `mcpServers` options, `documents` for agent identity files, managed mode (blocks CLI config mutation), and a persistent container mode with podman support. No other agent framework in this space offers comparable Nix integration. ZeroClaw has a `flake.nix` for building but no NixOS module, no declarative config, and no service management.

**Podman container isolation.** Hermes's NixOS module has `container.backend = "podman"` as a first-class option (PR #10066, merged 2026-04-15). The container runs a persistent Ubuntu image with `/nix/store` bind-mounted read-only. The CLI transparently routes into the container. This replaces the planned systemd-nspawn approach with less custom wiring and better upstream support.

**Fully declarative configuration.** Every aspect of the deployment, model providers, Telegram bot token, MCP servers, agent personality, memory settings, is declared in `configuration.nix` and managed via `nixos-rebuild switch`. Secrets flow through sops-nix. Managed mode prevents config drift.

**Superior memory system.** Hermes has three memory layers: built-in bounded memory (MEMORY.md/USER.md injected into system prompts), FTS5 session search across all past conversations, and 8 external memory provider plugins. Four providers are fully self-hostable at no cost: Holographic (local SQLite, zero deps), OpenViking (self-hosted server), Hindsight (local PostgreSQL mode), and ByteRover (local CLI). Honcho (dialectic user modelling) is self-hostable or available as a hosted service for future use. ZeroClaw's SQLite hybrid search is capable but is a single-tier system with known operational bugs (#4916 snowball, #5113 broken clear).

**Mature Telegram integration.** Bot menu integration, slash command autocomplete, voice memo transcription, link preview control, private chat topics with per-topic session isolation, streaming via progressive message editing. Active development (Telegram-specific commits landing daily as of April 2026).

**Ecosystem momentum.** 90k stars, 445 contributors, 4,300 commits, 8 releases in under 2 months. Backed by Nous Research (AI research lab). The development pace exceeds both PicoClaw and ZeroClaw by an order of magnitude.

**What was traded:**

- **Automatic task-based model routing.** ZeroClaw's `[[model_routes]]` with `[query_classification]` provided automatic hint-based routing (coding → endpoint A, reasoning → endpoint B). Hermes offers smart routing (simple vs complex binary split), manual `/model` switching between named custom providers, delegation (subagents use a different model), and auxiliary model routing (vision, compression, web extraction → separate endpoints). Full capability-based routing is an open feature request (issue #157). For a first-time agent deployment, manual selection with smart routing is an acceptable starting point.
- **Rust binary.** ZeroClaw's < 5 MB RAM footprint and < 10 ms startup are impressive. Hermes is Python (~100-200 MB baseline). On 64-128 GB hosts, this is a rounding error.
- **Explicit Tailscale tunnel config.** ZeroClaw has a `[tunnel]` config section with Tailscale/Cloudflare providers. Hermes has no built-in tunnel management. Since the Tailnet is configured at the NixOS host level and llama-swap instances bind to Tailscale addresses, this is transparent and requires no agent-level tunnel config.

**Honcho as a future improvement.** Honcho (dialectic user modelling, cross-session reasoning) is the most sophisticated memory provider available. Self-hosting requires PostgreSQL + pgvector, a FastAPI server, a background deriver worker, and LLM API keys for the reasoning pipeline. The hosted service offers $100 free credits on sign-up, usage-based pricing ($2/M tokens ingestion, unlimited retrieval, $0.001-$0.50/query for reasoning). The plan is to start with Holographic (local SQLite, zero dependencies) and graduate to Honcho once operational experience with Hermes is established.

---

## Historical Research: PicoClaw vs ZeroClaw

The research below was conducted 2026-04-11 and informed the initial decision to use ZeroClaw. It is retained for reference but is no longer the active recommendation.

## Recommendation (historical, superseded by Hermes)

ZeroClaw is the right choice. Across the six core criteria researched in depth, ZeroClaw leads on five: memory, model routing, web UI, Cloudflare Tunnel integration, and GitHub Copilot Pro support. PicoClaw leads on documentation quality and nspawn deployment simplicity (zero nspawn-specific config vs one sandbox override line). That is a 5-to-2 split, and the two areas where PicoClaw leads are the least architecturally consequential - documentation improves faster than runtime capabilities, and a single `backend = "none"` line is not a meaningful deployment burden.

The Go language preference is noted but does not change this conclusion. Martin's own framing applies symmetrically: if "just being written in Rust is not a selling point," then being written in Go is equally not a selling point when the functional gap is this consistent. Model routing alone would justify the choice given the stated priority of right-sizing models per task - ZeroClaw offers named hint pools, per-domain classification rules, runtime self-modification, and integrated cost tracking with budget enforcement, where PicoClaw offers a binary light/heavy threshold. The embedded web dashboard, managed tunnel support, and native Copilot OAuth widen the gap further.

Both projects launched in February 2026 and remain pre-v1.0. The decision is low-cost to reverse: config formats map 1:1, no data migration is needed, and switching costs a config rewrite plus a systemd unit change. Start with ZeroClaw and revisit only if its operational bugs (broken `memory clear`, snowball workaround, Landlock poisoning) prove more disruptive than expected.

## Comparison Table

| Criterion | PicoClaw | ZeroClaw | Verdict |
|---|---|---|---|
| **Documentation** | Dedicated docs site (docs.picoclaw.io) with config reference, per-channel guides, MCP setup, credential encryption docs, tool configuration. Docusaurus-based, searchable. | Wiki on GitHub (partially outdated by their own admission). Mintlify-hosted reference docs exist but are fragmented across multiple domains. AGENTS.md in-repo is thorough for contributors. | PicoClaw wins |
| **Code quality & design** | Go, ~28k stars, 30 contributors, MIT licence. v0.2.6 as of April 2026. Cobra CLI, clean package layout (pkg/agent, pkg/tools, pkg/channels). Nightly builds. Weekly stable releases since March. | Rust, ~30k stars, 30 contributors, Apache-2.0 licence. v0.6.9 as of April 2026. Trait-driven architecture, higher version number reflects faster minor bumps. Pre-push hooks enforced. Both have similar release cadence. | Draw - both are early-stage with active development |
| **Security** | AES-256-GCM credential encryption (two-factor: passphrase + SSH key). Workspace sandbox with restrict_to_workspace. Shell command denylist. SSRF protection added. Open bug: credential leakage via subagent tool output (#972). Security audit disclosed (#321), partially addressed. | ChaCha20-Poly1305 secret encryption. Device pairing with hashed tokens. Autonomy levels (readonly/supervised/full). Sandbox trait with Docker/Firejail/Landlock backends. More defence-in-depth layers by default. | ZeroClaw wins on defaults; PicoClaw has an open credential bug (#972) |
| **Integrations** | Telegram, Discord, Slack, WhatsApp, WeChat, QQ, LINE, DingTalk, Feishu, MaixCam. MCP: stdio + SSE + HTTP transports with lazy discovery. 30+ LLM providers. Ollama via OpenAI-compatible endpoint. | Telegram, Discord, Slack, WhatsApp, Signal, iMessage, Matrix, IRC, Email, Bluesky, Nostr, Mattermost, Nextcloud Talk, DingTalk, Lark, QQ, Reddit, MQTT. MCP: stdio + SSE transports. 28+ LLM providers. Native Ollama provider. | ZeroClaw has more channels; both cover the required set (Telegram, Discord, Ollama, MCP) |
| **Community** | 28k stars, Discord + WeChat groups. Sipeed (hardware company) is the primary maintainer. Chinese-language community is large. English community growing. | 30k stars, Discord + Telegram groups. Built by Harvard/MIT/Sundai.Club community. English-first. More third-party blog coverage. | ZeroClaw wins for English-first users |
| **Interchangeability** | JSON config (~/.picoclaw/config.json). model_list array for providers. channels block for messaging. tools.mcp block for MCP servers. | TOML config (~/.zeroclaw/config.toml). providers section. channels_config block. mcp block. zeroclaw migrate --from openclaw exists. | Different formats but same concepts; switching is a config rewrite, not an architecture change |

## Detailed Notes

### 1. Documentation

PicoClaw has a proper documentation site at docs.picoclaw.io built on Docusaurus. It covers installation, configuration overview, per-channel setup guides (Telegram, Discord, WhatsApp, etc.), MCP tool configuration with examples for stdio/SSE/HTTP transports, credential encryption, security sandbox, full config reference with annotated JSON, and environment variable overrides. The docs are versioned and searchable.

ZeroClaw's documentation is split across a GitHub wiki (acknowledged as partially outdated), Mintlify-hosted reference docs, a docs/ directory in the repo, and multiple third-party domains (zeroclaws.io, zeroclaw.net, zeroclaw.dev) of uncertain official status. The in-repo AGENTS.md is excellent for contributors but not for users. The wiki table of contents is comprehensive in scope but the content lags behind the code. Channel-specific docs (e.g. Telegram on Mintlify) are detailed where they exist.

PicoClaw's documentation is more cohesive and reliable as a single source of truth.

### 2. Code Quality, Robustness, and Design

Both projects are two months old. Neither should be considered mature.

PicoClaw is written in Go with a conventional structure: cmd/picoclaw for the CLI entrypoint (Cobra), pkg/ for library packages (agent, tools, channels, config, providers, etc.). The codebase is reportedly 95% AI-generated with human refinement, which is a risk factor for subtle bugs but the architecture is clean. Test coverage is not prominently documented.

ZeroClaw is written in Rust with a trait-driven architecture. Providers, channels, tools, memory, and tunnels are all swappable via traits. The Rust compiler provides memory safety guarantees that Go does not. The project enforces pre-push hooks (fmt + clippy + test). The AGENTS.md file is unusually disciplined about code standards for a young project.

Both ship as single static binaries with sub-second boot times. Release cadence is similar: both ship roughly weekly stable releases with nightly builds.

### 3. Security

Both projects implement credential encryption at rest, workspace sandboxing, and channel allowlists. The approaches differ:

PicoClaw uses AES-256-GCM with a two-factor key derivation (passphrase + SSH private key via HKDF). The threat model is documented. The sandbox restricts file system access to the workspace directory and maintains a shell command denylist. SSRF protection was added after a security audit disclosure. An open critical bug (#972) allows subagents to leak credentials via tool output when models attempt to "fix" configuration errors autonomously, as there is no secret redaction layer in the tool output pipeline.

ZeroClaw uses ChaCha20-Poly1305 with a locally-stored key file. It adds device pairing (one-time bind codes for new channels), autonomy levels (readonly/supervised/full), and pluggable sandbox backends (Docker, Firejail, Landlock, native). The gateway binds to 127.0.0.1 by default and refuses 0.0.0.0 without explicit configuration.

ZeroClaw's security model is deeper by default, with more layers (pairing, autonomy levels, pluggable sandboxing). PicoClaw's credential encryption design is arguably more principled (two-factor vs single key file). PicoClaw has an open credential leakage bug (#972) where subagents can expose secrets via tool output. Neither has had a formal CVE assigned against it, though OpenClaw (the parent ecosystem) has.

For deployment inside systemd-nspawn containers, the container itself provides the primary isolation layer. The agent's built-in sandboxing is a secondary concern.

### 4. Integration Capability

Both projects cover the required integration surface:

**Telegram**: Both support Bot API via long polling. PicoClaw uses JSON config with allow_from user IDs. ZeroClaw uses TOML with allowed_users. Both support group triggers, mention-only mode, and streaming. ZeroClaw adds pairing mode where the first message requires a one-time code.

**Discord**: Both support gateway/websocket delivery. Configuration is similar, group trigger controls, allowlists. PicoClaw adds voice channel support (join/leave, TTS/ASR).

**Ollama**: PicoClaw connects via the OpenAI-compatible endpoint (http://localhost:11434/v1) using provider "openai" with an empty api_key. ZeroClaw has a native Ollama provider with dedicated config, which is cleaner.

**MCP**: Both support stdio and SSE transports. PicoClaw also supports HTTP transport. PicoClaw has lazy tool discovery (BM25 keyword matching to avoid context window exhaustion) with configurable TTL. PicoClaw's MCP implementation appears more mature.

**Frontier model providers**: Both support Anthropic, OpenAI, Google Gemini, OpenRouter, and 20+ others via OpenAI-compatible endpoints.

### 5. Community

Both projects exploded in popularity in February 2026 as part of the "claw" ecosystem wave following OpenClaw's security crisis.

PicoClaw: 28,007 stars, 3,967 forks, 282 open issues, 30 contributors. Maintained by Sipeed, a Chinese hardware company. Community skews Chinese-language with growing English presence. Discord and WeChat groups.

ZeroClaw: 29,954 stars, 4,300 forks, 333 open issues, 30 contributors. Built by Argenis De La Rosa and contributors from Harvard/MIT/Sundai.Club communities. Community is English-first. Discord and Telegram groups. More coverage on English-language tech blogs.

Star counts and fork counts are comparable. Neither has a dominant community advantage for an English-speaking NixOS user.

### 6. Interchangeability

The two projects solve the same problem with the same architecture (gateway + agent loop + channels + tools + providers). Concepts map directly:

| PicoClaw (JSON) | ZeroClaw (TOML) |
|---|---|
| model_list[].model | providers.\<name\> |
| channels.telegram | channels_config.telegram |
| tools.mcp.servers | mcp.servers |
| agents.defaults.model | default_model / agent.model |
| heartbeat | heartbeat |
| gateway.host/port | gateway.host/port |

Switching from one to the other requires rewriting the config file and adjusting systemd unit invocations. No data migration is needed for the target use case (no existing conversation history or memory to preserve).

ZeroClaw ships a `zeroclaw migrate --from openclaw` command but not a picoclaw migration path. The reverse does not exist either. Manual config translation is straightforward given the 1:1 concept mapping.

## Sources

- PicoClaw GitHub: https://github.com/sipeed/picoclaw (28k stars, MIT, Go)
- PicoClaw docs: https://docs.picoclaw.io/
- ZeroClaw GitHub: https://github.com/zeroclaw-labs/zeroclaw (30k stars, Apache-2.0, Rust)
- ZeroClaw wiki: https://github.com/zeroclaw-labs/zeroclaw/wiki
- Hermes Agent GitHub: https://github.com/NousResearch/hermes-agent (90k stars, MIT, Python)
- Hermes Agent docs: https://hermes-agent.nousresearch.com/docs/
- Hermes NixOS setup guide: https://hermes-agent.nousresearch.com/docs/getting-started/nix-setup
- Hermes memory providers: https://hermes-agent.nousresearch.com/docs/user-guide/features/memory-providers
- Hermes AI providers: https://hermes-agent.nousresearch.com/docs/integrations/providers
- Honcho GitHub: https://github.com/plastic-labs/honcho (2.5k stars, AGPL-3.0, Python)
- Honcho pricing: https://honcho.dev/#pricing
