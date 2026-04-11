# PicoClaw vs ZeroClaw - Comparison for NixOS Agent Deployment

Last updated: 2026-04-11

## Recommendation

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

## Run Both vs Pick One

Pick one. Running both creates double the configuration surface, double the systemd units, double the MCP server instances, and double the monitoring burden for no functional benefit. Both tools do the same thing. The only reason to run both would be to evaluate them side-by-side for a few weeks before committing, which is reasonable as a time-boxed experiment but not as a permanent architecture.

If running a time-boxed evaluation: deploy both in separate nspawn containers, point them at different Telegram bots and Discord servers, give each the same MCP server configuration, and run the same tasks for two weeks. Measure response quality, reliability, and failure modes. Then pick one and decommission the other.

The recommended path: start with ZeroClaw (stronger memory, native Copilot OAuth, English-first community), deploy it properly, and only revisit PicoClaw if ZeroClaw's operational bugs prove more disruptive than expected.

## GitHub Copilot Pro and OpenCode Zen

### GitHub Copilot Pro as a Model Provider

Both projects support GitHub Copilot as a model backend, though neither treats it as a first-class onboarding path.

**ZeroClaw** has a native `CopilotProvider` in `src/providers/copilot.rs`. It implements the GitHub OAuth device-code flow (the same flow VS Code uses, with client ID `Iv1.b507a08c87ecfe98`), exchanges the OAuth token for short-lived Copilot API keys, caches tokens to disk, and auto-refreshes them. Configuration is minimal: set `default_provider = "copilot"` and `default_model = "gpt-5-mini"` in `config.toml`, then run `zeroclaw agent` and complete the device login prompt. The provider is not yet exposed in the `zeroclaw onboard` wizard (open issue #4851, labelled S1-workflow-blocked), so setup requires manual config editing. Once authenticated, it works with any model your Copilot subscription grants access to.

**PicoClaw** lists `github-copilot/` as a supported vendor prefix in its `model_list` configuration. The default API base is `localhost:4321` and the connection mode is gRPC, which means PicoClaw expects a local Copilot proxy (such as `copilot-api` or `copilot-router`) running separately rather than handling the OAuth flow itself. This is a meaningful difference: ZeroClaw handles authentication natively, PicoClaw delegates it to an external process. Running a proxy adds a moving part to the deployment. However, PR #2240 (opened 2026-04-01, still open) adds a native stdio transport using the GitHub Copilot SDK, which would eliminate the external proxy requirement and bring PicoClaw closer to parity with ZeroClaw's built-in OAuth flow. This is not on a formal roadmap or milestone - it is a community contribution awaiting review.

Neither project documents Copilot integration thoroughly. ZeroClaw's exists in source but not in onboarding docs. PicoClaw's exists in the provider table but the gRPC/proxy requirement is not explained beyond the default values.

**Practical assessment**: A GitHub Copilot Pro subscription provides access to Claude, GPT, and Gemini models at a fixed monthly cost, making it attractive as a provider for agent workloads. ZeroClaw's native OAuth flow is the cleaner path. PicoClaw's proxy requirement is workable but adds a second long-running process to manage alongside the agent.

### OpenCode Zen as a Model Provider

OpenCode Zen is an AI gateway operated by the OpenCode team (the open-source coding agent, 140k+ GitHub stars). It is not a model or a tier within OpenCode - it is a pay-as-you-go API proxy that routes requests to curated, benchmarked models optimised for coding agents. The API base is `https://opencode.ai/zen/v1` and it exposes OpenAI-compatible (`/chat/completions`, `/responses`) and Anthropic-compatible (`/messages`) endpoints depending on the model.

Current model catalogue includes GPT 5.4, GPT 5.3 Codex, Claude Opus 4.6, Claude Sonnet 4.5, Gemini 3 Pro, MiniMax M2.5/M2.7, GLM 5.1, Kimi K2.5, and several free models (Big Pickle, Qwen3.6 Plus, Nemotron 3 Super). Pricing is per-token with zero markup, billed against a prepaid balance with $20 auto-top-up.

**Neither PicoClaw nor ZeroClaw has a built-in OpenCode Zen provider.** However, because Zen exposes standard OpenAI-compatible and Anthropic-compatible endpoints, both agents can use it as a custom provider:

- PicoClaw: add a `model_list` entry with `"model": "openai/<model-id>"`, `"api_base": "https://opencode.ai/zen/v1"`, and the Zen API key in `api_keys`.
- ZeroClaw: add a custom provider in `config.toml` with the Zen base URL and API key, using the OpenAI-compatible protocol.

This is a standard "any OpenAI-compatible endpoint" configuration, not a special integration. It should work but is untested by either project's maintainers. Zen's zero-retention privacy policy and US-hosted infrastructure are relevant positives for agent workloads.

OpenClaw (the separate, larger project) does document OpenCode Zen as a named provider with `openclaw onboard --auth-choice opencode-zen`. Neither PicoClaw nor ZeroClaw has followed suit.

### Summary

| Provider | PicoClaw | ZeroClaw |
|---|---|---|
| **GitHub Copilot** | Supported via external proxy (gRPC to localhost:4321). Requires running copilot-api or copilot-router alongside the agent. No native OAuth. | Native provider with built-in OAuth device-code flow. Manual config required (not in onboard wizard yet). |
| **OpenCode Zen** | No built-in support. Works as a custom OpenAI-compatible endpoint via model_list. | No built-in support. Works as a custom OpenAI-compatible endpoint via provider config. |

For GitHub Copilot Pro, ZeroClaw is the better choice due to native authentication. For OpenCode Zen, neither has an advantage - both treat it as a generic OpenAI-compatible endpoint.

## Memory

ZeroClaw has a substantially more capable memory system. PicoClaw uses flat markdown files with no search; ZeroClaw uses SQLite with hybrid vector + FTS5 keyword search, multiple backend options, automatic hygiene, and a full CLI for inspection. Both persist memory across sessions, but ZeroClaw treats memory as a first-class subsystem while PicoClaw treats it as prompt injection from a file.

| Aspect | PicoClaw | ZeroClaw |
|---|---|---|
| **Persistent across sessions** | Yes. `MEMORY.md` loaded into system prompt at session start. Daily notes (`YYYY-MM/DD.md`) for chronological context. | Yes. Configurable backend persists all memory entries. Auto-save after each turn by default. |
| **Storage mechanism** | Flat markdown files (`~/.picoclaw/workspace/memory/MEMORY.md` + daily notes). Seahorse short-term memory engine adds per-agent SQLite (`seahorse.db`) with FTS5 since v0.2.5. | Pluggable backends: SQLite (default, `brain.db`), PostgreSQL, Markdown files, Lucid (external vector CLI), or None. SQLite uses hybrid vector + FTS5 BM25 search. |
| **Scoping** | Global per workspace. `MEMORY.md` is shared by all sessions. Per-user overlays proposed (PR #1033) but `MEMORY.md` remains global. Session history is per-channel via `dm_scope` setting. | Per-session via `session_id` on each entry. Categories (`Conversation`, `Facts`, `Core`) allow filtering. Multi-instance sharing possible via PostgreSQL backend. |
| **User inspection/editing** | Direct file editing - `MEMORY.md` is plain text. `rm` to clear. No CLI subcommand for memory management. Session files in `sessions/` are JSON/JSONL, editable but not designed for it. | Full CLI: `zeroclaw memory list`, `zeroclaw memory list --category facts`, `zeroclaw memory stats`, `zeroclaw memory clear`. SQLite file also inspectable with any SQLite client. Snapshot export to `MEMORY_SNAPSHOT.md` for git visibility. |
| **Size/token limits** | No hard limit on `MEMORY.md` size - entire file loaded into system prompt, consuming context window tokens. Session summarisation triggers at 20 messages or 75% context window usage (both configurable since PR #1029). Seahorse engine adds hierarchical summarisation with FTS5 indexing. | No hard limit on entry count. Hygiene system auto-archives entries after 7 days and purges after 30 days (configurable via `archive_after_days`, `purge_after_days`). Embedding token limits apply per-chunk. `auto_save` filtering skips synthetic content (cron output, heartbeat tasks, distilled summaries). |
| **Summarisation** | Session history summarised by LLM when thresholds exceeded. Summary replaces older messages. Configurable via `memory_message_limit` and `memory_token_percent`. | No explicit session summarisation - relies on memory recall selecting relevant entries via hybrid search scoring. Conversation retention configurable via `conversation_retention_days` (default 30). |
| **Search/retrieval** | No search on `MEMORY.md` (loaded wholesale). Seahorse engine provides FTS5 `short_grep` and `short_expand` tools for short-term memory. No semantic/vector search. | Hybrid search: FTS5 BM25 keyword + cosine vector similarity, merged via Reciprocal Rank Fusion. Configurable `keyword_weight` (default 0.3). Embedding cache with LRU eviction reduces API calls. Sub-3ms retrieval on Raspberry Pi hardware. |

### PicoClaw Memory Details

PicoClaw's memory is deliberately simple. The agent reads `MEMORY.md` and the last 3 days of daily notes at session start, injecting them into the system prompt. The agent writes to these files using standard file tools - there is no dedicated memory API. Atomic writes (`WriteFileAtomic`) protect against corruption on crash or flash storage.

The Seahorse short-term memory engine (added in v0.2.5) is the first step toward structured memory. It stores per-agent conversation data in SQLite with FTS5 full-text indexing, two-tier hierarchical summarisation (leaf summaries condensed into higher-level summaries), and registers `short_grep`/`short_expand` tools so the agent can search its own recent history. This addresses the "no search" limitation of `MEMORY.md` but only for short-term session context, not long-term facts.

Known limitations:
- `MEMORY.md` grows unbounded and consumes context window tokens proportionally. No automatic pruning or summarisation of the long-term memory file itself.
- Multi-user gap (#995): `MEMORY.md` is global per workspace. Multiple users sharing one instance get a shared memory with no isolation. Per-user memory overlays were contributed (PR #1033) but the base `MEMORY.md` remains shared.
- No semantic search on long-term memory. Feature request for Engram integration (#175) remains open.

### ZeroClaw Memory Details

ZeroClaw's memory is a trait-based pluggable system with five backends. The SQLite backend is production-grade: hybrid vector + FTS5 keyword search with configurable weighting, embedding cache, automatic hygiene (archive/purge lifecycle), ACID transactions, and WAL mode for concurrent reads. The entire memory lives in a single `brain.db` file, portable via copy.

The snapshot system exports `Core` category memories to `MEMORY_SNAPSHOT.md` for git visibility and disaster recovery. If `brain.db` is lost, the agent auto-hydrates from the snapshot on next startup.

Memory categories (`Conversation`, `Facts`, `Core`) allow structured organisation. The agent's `memory_recall` tool performs hybrid search to retrieve relevant entries within a token budget rather than loading everything into the prompt.

Known limitations:
- Auto-save recursive snowball (#4916, S1 severity): `auto_save` re-ingested `[Memory context]` recall blobs, causing exponential growth. Production instances hit 888MB `brain.db` files and became unresponsive. Fix: filter `[Memory context]` prefixes from auto-save path.
- `memory clear` broken (#5113, open as of April 2026): `zeroclaw memory clear` reports "Cleared 0/N entries" even after confirmation. Users cannot clear memory via CLI without manual SQLite operations.
- Wildcard recall failure (#5170): `memory_recall` with `query: "*"` returns empty results because FTS5 cannot match a literal asterisk. LLMs commonly issue this query to retrieve all context.
- No built-in vector search for PostgreSQL backend (requires pgvector extension). Markdown backend has no search at all.

### Verdict

ZeroClaw wins decisively on memory capability. For a long-running agent deployment where accumulated context matters, ZeroClaw's SQLite hybrid search, automatic hygiene, CLI management, and snapshot/hydration cycle are materially better than PicoClaw's flat-file approach. PicoClaw's Seahorse engine narrows the gap for short-term session memory but does not address long-term knowledge retrieval. The recursive snowball bug (#4916) and broken `memory clear` (#5113) are serious operational concerns for ZeroClaw, though the snowball bug has a known workaround and a fix PR.

## Project Direction

Research date: 2026-04-11. Based on open/closed issues, open/merged PRs, milestones, ROADMAP.md files, release notes, and Mintlify docs for both projects.

### Comparison Table

| Criterion | PicoClaw | ZeroClaw |
|---|---|---|
| **Dominant issue themes** | Provider compatibility (model switching #1749), long-running agent degradation (#1641). Chinese-language channel bugs (QQ #2080, WeChat) are frequent but irrelevant to this deployment. | Sandbox/runtime bugs (Landlock poisoning #5153, systemd fork duplication #5232, file_write invisibility #4627), memory system defects (#4916 snowball, #5113 broken clear, #5170 wildcard). Context compression does not trigger in daemon mode (#4880). |
| **Active PR focus** | Agent architecture refactor (SubTurn, Hooks, Steering, EventBus landed in v0.2.4), provider hardening (rate limiting #2198, model probe caching #2231), security (WebSocket origin check #2256), Seahorse short-term memory engine (#2285). New providers (Venice AI, Qwen CLI, MiMo). | Channel expansion (LINE #5490, improved Matrix E2EE), dashboard/web UI fixes (#5499, #4866), CI consolidation (#2895 replaced 22 workflows), ACP server mode (#4564/#4608), context overflow recovery and tool result truncation (v0.6.5), fuzz testing scaffolding (#5516), contributor coordination tooling (#4365). |
| **Stated roadmap goals** | ROADMAP.md: (1) extreme lightweight (<20MB on 64MB RAM boards), (2) security hardening, (3) protocol-first provider architecture, (4) multi-agent/swarm mode, (5) developer experience, (6) AI-powered CI. Milestones: "Refactor Channel" complete, "Refactor Agent" 91% complete with Phase 2 multi-agent (#1934) remaining. | Mintlify roadmap: Q1 2026 security phase 1 (Landlock, memory monitoring, CPU timeouts), Q2 security phases 2-3 (Firejail, Bubblewrap, cgroups, Docker mode, signed configs), Q3 feature expansion (streaming, multi-agent, enhanced memory), Q4 platform expansion. No ROADMAP.md in-repo yet (requested in #4365). |
| **v1.0 readiness signal** | README explicitly warns "Do not deploy to production before v1.0." No v1.0 milestone exists. Current version v0.2.6. At current pace (0.2.0 to 0.2.6 in six weeks), v1.0 is months away at minimum. | No v1.0 milestone. Current version v0.6.9 (higher number but reflects faster minor bumps, not greater maturity). Mintlify roadmap extends through Q4 2026 without mentioning a 1.0 gate. Neither project is close to a stability release. |

### PicoClaw: Issues, PRs, and Roadmap

PicoClaw's bug reports cluster around two themes: provider compatibility and long-running agent degradation.

**Provider compatibility** generates the highest volume of reports. The `/switch` command changed the model name but not the API base (#1749). Rate limiting for LLM calls landed via PR #2198 (merged April 2026). The pattern indicates the provider abstraction layer was not designed for the diversity of backends it now serves.

**Long-running agent degradation** (#1641) remains open - agents become less responsive over extended sessions. This is directly relevant to a persistent daemon deployment.

Active PR work focuses on the agent architecture refactor. The "Refactor Channel" milestone is 100% complete (44/44 issues closed). "Refactor Agent" is 91% complete (11/12 closed), with Phase 2 multi-agent collaboration (#1934) as the sole remaining item. The Seahorse short-term memory engine (#2285) landed in v0.2.5, adding SQLite-backed FTS5 for session context. Security PRs include WebSocket origin hardening (#2256).

Multi-agent collaboration is the most active area of architectural investment. No v1.0 milestone or timeline exists.

### ZeroClaw: Issues, PRs, and Roadmap

ZeroClaw's bugs cluster around sandbox/runtime behaviour and memory system defects.

**Sandbox and runtime bugs** are the most severe category. The Landlock sandbox poisons the parent process after a shell tool call (#5153, S1 severity), breaking cron, memory hygiene, session persistence, and cost tracking for the remainder of the daemon's lifetime. The systemd service generator produces `Type=simple` but the daemon forks (#5232, S1), causing duplicate responses on every channel. File writes succeed from the agent's perspective but are invisible on the host filesystem (#4627, S0). These are fundamental operational defects, not edge cases.

**Memory system defects** are documented in the Memory section above. The auto-save snowball (#4916), broken CLI clear (#5113), and wildcard recall failure (#5170) remain open as of April 2026.

Context compression does not trigger in daemon mode (#4880, open), which compounds the memory issues for long-running deployments.

Active PR work is split between infrastructure hardening and feature expansion. The lead maintainer (theonlyhennygod) consolidated 22 CI workflows into a streamlined pipeline (#2895), completed a 535-branch cleanup (#3247), and implemented ACP server mode over stdio (#4608). Community contributors are adding channels (LINE #5490), fixing the web dashboard (#5499), and wiring fuzz test targets (#5516). The v0.6.5 release added context overflow recovery, tool result truncation, per-session actor queues, and auth rate limiting - these are stabilisation features that address real operational failures.

The Mintlify roadmap lays out a four-quarter plan for 2026. Q1 focused on security phase 1 (Landlock, memory monitoring, CPU timeouts). Q2 targets Firejail/Bubblewrap sandboxing, cgroups, seccomp filtering, and Docker mode. Q3 plans streaming, multi-agent coordination, and enhanced memory. Q4 covers platform expansion. There is no ROADMAP.md in the repository itself - issue #4365 (opened by a collaborator) requests one, along with a GitHub Projects board and draft-PR-as-work-claim convention. The absence of in-repo coordination surfaces is a known gap. No v1.0 milestone or gate criteria exist.

### Trajectory Comparison

PicoClaw is building inward: refactoring its agent architecture, hardening providers, and adding structured memory (Seahorse). Its bugs are mostly fixed quickly. The maintainer team (Sipeed, led by yinwm and alexhoshina) runs a disciplined milestone-driven process - the channel refactor shipped complete, the agent refactor is nearly done. The project's trajectory points toward a more capable multi-agent system on a cleaner internal architecture.

ZeroClaw is building outward: adding channels, execution modes (ACP server), deployment targets (Termux, Docker, Coolify/Dokploy templates), and stabilisation features (context overflow recovery, rate limiting, session state machines). Its bugs are more operationally severe (Landlock poisoning, systemd fork duplication, invisible file writes) and some remain open. The lead maintainer is prolific but the project lacks formal coordination - no milestones, no ROADMAP.md, no project board. The trajectory points toward a broader platform with more deployment options but less architectural discipline.

For this NixOS deployment running as a systemd service inside nspawn containers, ZeroClaw's systemd service generation bug (#5232) and Landlock sandbox poisoning (#5153) are directly relevant operational risks. Both are workaroundable (use a hand-written service file with `Type=forking` or `--foreground`; disable Landlock inside nspawn where the container provides isolation). PicoClaw's systemd integration, while undocumented, does not have equivalent defects.

The directional difference does not change the recommendation. ZeroClaw's memory advantage and native Copilot OAuth remain the decisive factors. The sandbox and systemd bugs are deployment-time configuration problems, not architectural limitations. PicoClaw's inward focus on agent architecture may yield a better multi-agent system in the medium term, but multi-agent is not a stated requirement for this deployment. Monitor ZeroClaw's Landlock fix, use a custom systemd unit, and revisit if the Q2 2026 security phases ship on schedule.

## Model Routing

ZeroClaw has a substantially richer model routing system than PicoClaw. Both projects can route simple versus complex messages to different models, but ZeroClaw adds named hint-based routing with arbitrary categories, per-domain classification rules, runtime reconfiguration via a tool the agent itself can call, and integrated cost tracking with budget enforcement. PicoClaw's routing is a clean binary split (light vs heavy) that works well for its intended purpose but cannot express "use model X for summarisation, model Y for code review, model Z for reasoning."

| Capability | PicoClaw | ZeroClaw |
|---|---|---|
| **Named model pool** | `model_list` array with `model_name` aliases. Any alias can be referenced by agents. No typed categories beyond "light" and "primary". | `[[model_routes]]` with arbitrary `hint` names (e.g. `fast`, `reasoning`, `code`, `summarize`). `[model_providers.*]` named profiles (`fast`, `reasoning`, `local`). Hints are first-class routing targets. |
| **Per-agent model assignment** | Each agent in `agents.list` has its own `model` field with primary/fallback chain. Bindings route messages to agents by channel/account/context. Teams PR (#976, closed, v2 merged) adds per-member `model` field and capability `tags` (`vision`, `code`, `fast`, `reasoning`). | Each agent in `[agents]` has its own provider/model. Workspace routing bindings (PR #2871, merged) map `(channel, account, peer)` to agent with per-agent provider/model. Swarm tool supports per-member model assignment. |
| **Per-task/domain routing** | Binary: `routing.enabled`, `routing.light_model`, `routing.threshold`. A `RuleClassifier` scores message complexity on structural signals (token count, code blocks, tool call density, attachments, conversation depth). Score below threshold goes to light model, above goes to primary. No keyword, intent, or domain matching. Issue #295 (open, roadmap) discusses per-tool routing as a v2 feature. | `[query_classification]` with priority-sorted rules matching keywords, patterns, or message properties to emit routing hints. Hints resolve to `[[model_routes]]` entries. `RouterProvider` also supports `hint:cost-optimized` which filters by capability and sorts by cost. Classification initially worked only in agent mode; PR #1685 extended it to channels. |
| **Fallback and escalation** | `FallbackChain` with ordered candidates. Reactive: triggers on HTTP errors (429, 5xx, timeout). Proactive rate limiting via per-model `rpm` token buckets. Cooldown tracker skips recently-failed candidates. No quality-based escalation. | `[reliability]` section with `fallback_providers`, `model_fallbacks` (map of model to fallback list), `max_retries`, `initial_backoff_ms`. Triggers on 429, 503, connection failure, auth error, model-not-found. API key rotation before provider fallback. No quality-based escalation in either project. |
| **Token/cost tracking** | No built-in tracking. Rate limiter tracks request counts for throttling but does not log token usage or cost. No CLI command for usage summary. External proxy (CostMeter, burn0) required. | `[cost]` section in config with `enabled`, `daily_limit_usd`, `monthly_limit_usd`, `warn_at_percent`. `CostTracker` persists to `costs.jsonl`, calculates cost from built-in per-model pricing tables. `get_summary()` returns session/daily/monthly totals. Budget enforcement blocks requests exceeding limits. OTLP/Prometheus observability backends emit `zeroclaw.tokens.used` counters and `zeroclaw.llm.duration` histograms. Issue #3565 (open) proposes a CLI `usage` subcommand and web dashboard. |
| **Runtime configurability** | Config read at startup. Environment variable overrides (`PICOCLAW_AGENTS_DEFAULTS_MODEL_NAME`, etc.) require restart. No hot-reload. Web UI can edit config but requires agent restart to apply routing changes. | `[reliability]` section is hot-reloadable - channel runtime watches `config.toml` and applies changes to `default_provider`, `default_model`, and routing without restart. `ModelRoutingConfigTool` allows the agent to inspect and modify routing rules and classification rules at runtime via tool calls (`get`, `set_route`, `add_classification_rule`). Per-sender `/model` commands in Telegram/Discord switch model without daemon restart. Limitation: route preferences reset on daemon restart (issue noted in wiki). |

### Where the projects differ materially

**Classification granularity.** PicoClaw's `RuleClassifier` is a pure structural heuristic: it scores on token count, code block presence, tool call density, attachment presence, and conversation depth. The weights are hardcoded (e.g. code block = 0.40, attachments = 1.00 hard gate). This is fast (sub-microsecond, zero API calls) and predictable, but it cannot distinguish between domains. A 50-word request to summarise a document and a 50-word request to review code score identically unless the code request contains a code block. ZeroClaw's `query_classification` adds keyword and pattern matching on top of its own complexity heuristics, so you can write rules like "messages containing 'summarise' or 'tldr' route to hint `fast`" and "messages containing 'review', 'audit', or 'security' route to hint `reasoning`". The classification rules are user-defined in config, not hardcoded.

**Runtime self-modification.** ZeroClaw's `ModelRoutingConfigTool` is distinctive: the agent can ask itself to add or change routing rules during a conversation. A user can say "from now on, use the local model for translations" and the agent can persist that as a classification rule. This is gated by the security policy (requires write access). PicoClaw has no equivalent - routing changes require editing `config.json` and restarting.

**Cost-aware routing.** ZeroClaw's `hint:cost-optimized` route filters candidate models by required capabilities (vision, native tools) then sorts by cost, selecting the cheapest qualifying model. Combined with the `CostTracker` and budget limits, this creates a feedback loop where spending can be constrained automatically. PicoClaw has no cost awareness in the routing layer.

**Teams and capability tags.** PicoClaw's Teams architecture (v2 merged, successor to PR #976) adds `tags` to models (`vision`, `code`, `fast`, `long-context`, `reasoning`) and lets the coordinator select models by capability for each team member. This is closer to ZeroClaw's hint system conceptually, but operates at the multi-agent orchestration layer rather than the per-message routing layer. ZeroClaw's `SwarmTool` provides similar orchestration (sequential, parallel, fan-out, router-selected) with per-agent model assignment.

### Roadmap direction

PicoClaw's issue #295 (open, labelled `type: roadmap`, `priority: medium`) explicitly calls for per-tool routing and more sophisticated classification as v2 features. The `Classifier` interface is designed for swappable implementations (ML-based, embedding-based). The current rule-based classifier is described as v1. Active development is visible but the issue has been open since February 2026 with no milestone target.

ZeroClaw's routing is further along but still evolving. Issue #3565 (open) proposes structured token/cost logging with a CLI dashboard and web UI. The `ModelRoutingConfigTool` shipped in the core tool registry, making runtime routing a first-class feature. The channel-side classification gap (issue #1367, fixed by PR #1685) shows the team is actively closing integration gaps.

**What "right-sizing over time" looks like practically.** With ZeroClaw, you define `[[model_routes]]` entries for `local-fast` (Ollama/llama3), `local-smart` (Ollama/larger model), and `frontier` (Anthropic/OpenAI), write `[query_classification]` rules to route by pattern, enable `[cost]` tracking with daily limits, and let the agent refine its own rules via `model_routing_config`. The feedback loop is: observe cost breakdown, adjust classification rules (or let the agent adjust them), verify via runtime trace logs. With PicoClaw, you set `routing.light_model` to a local model and adjust the `threshold` float. Everything above threshold goes to the primary model. There is no middle tier, no domain routing, no cost feedback. You can approximate more tiers using agent bindings (route different channels to different agents with different models), but this requires pre-segmenting by channel rather than by task type. For the stated goal of right-sizing model selection per task, ZeroClaw is the clear choice today.

## Web UI and Cloudflare Tunnel

Both projects ship a web UI. ZeroClaw's is bundled into the gateway binary and substantially more capable. PicoClaw's is a separate launcher binary with a narrower feature set but active development. Neither project's web UI changes the recommendation - messaging channels remain the primary interface for this deployment - but ZeroClaw's dashboard is useful for operational visibility.

### Comparison Table

| Criterion | PicoClaw | ZeroClaw |
|---|---|---|
| **Web UI ships with binary** | No. Separate `picoclaw-launcher` binary required (built via `make build-launcher`). Gateway alone serves only webhook handlers and health endpoints. | Yes. Dashboard embedded in the gateway binary, served directly at the gateway port. `zeroclaw gateway` or `zeroclaw daemon` starts both. |
| **Feature scope** | Chat interface (via Pico WebSocket channel), model/channel configuration forms, gateway process start/stop, log viewer, system tray integration. Token dashboard requested but not implemented (#2217, open). | Dashboard (health, uptime, cost), agent chat, memory browser, config editor, cron manager, tool browser, log viewer, cost/token tracking, doctor diagnostics, integrations status, device pairing management. Cross-channel dashboard shipped in #4519/#4571. |
| **Authentication** | In-memory dashboard token per run. Persistent token via `PICOCLAW_LAUNCHER_TOKEN` env var. No OAuth, no multi-user. Docker docs explicitly warn against public exposure. | Pairing-based: 6-digit TOTP code on first connect, then bearer token (SHA-256 hashed, persisted to `config.toml`). Optional `auth_token` in `[web]` config. Rate-limited `/pair` endpoint prevents brute force. |
| **Technology** | Go backend (`web/backend/`), React + Vite + Tailwind frontend (`web/frontend/`), jotai state management, TanStack Router. Bubble Tea TUI alternative for headless. Flutter GUI also exists (`picoclaw_fui`, separate repo, 1 star). | Rust/Axum backend, React 19 + Vite 6 + Tailwind CSS 4 frontend. Single-file HTML fallback (`static/web/index.html`) with marked.js + highlight.js. No TUI dashboard equivalent. |
| **Bind address** | Launcher listens on `localhost:18800` by default. `-public` flag enables `0.0.0.0`. Gateway listens on `127.0.0.1:18790`. `host: "0.0.0.0"` enables LAN access, no guard. | Gateway listens on `127.0.0.1:42617` (or `:3000` per Mintlify docs, version-dependent). Refuses `0.0.0.0` unless a tunnel is active or `allow_public_bind = true` is set. This is a meaningful safety default. |
| **Tunnel support** | None built in. Manual reverse proxy (nginx, Caddy) or external tunnel (ngrok, cloudflared) required. Docs mention ngrok for LINE webhooks. No tunnel configuration in config.json. | Native `[tunnel]` config section with providers: `cloudflare`, `tailscale`, `ngrok`, `pinggy`, `openvpn`, `custom`. Cloudflare tunnel wraps `cloudflared tunnel run`, extracts public URL from stderr, health-checks the child process. Tailscale tunnel supports both `serve` (tailnet) and `funnel` (public). |
| **Webhook delivery** | Telegram and Discord use long polling only. LINE, WhatsApp, Slack, DingTalk, Feishu use inbound webhooks on the gateway port (`/webhook/line`, etc.). No Telegram webhook mode. | Telegram and Discord use long polling/gateway WebSocket. WhatsApp, Linq, WATI, Nextcloud Talk use inbound webhooks with HMAC signature verification. Generic `/webhook` endpoint with optional secret header. No Telegram webhook mode either. |
| **Security posture for exposure** | No auth on gateway HTTP endpoints (noted in #101 comments). Launcher has token auth but warns against public exposure. No rate limiting on gateway. `allow_from` on channels only. | Pairing required by default. Bearer token on all `/api/*` endpoints. Rate limiting on `/pair` and webhooks (`webhook_rate_limit_per_minute`). `trust_forwarded_headers` defaults to false. Idempotency layer prevents duplicate webhook processing. Security response headers added in v0.1.8. |
| **Mobile/responsive** | Launcher described as "cross-device access" with responsive layout. Flutter GUI (`picoclaw_fui`) targets mobile/TV with large buttons. | No explicit mobile design mentioned. React 19 + Tailwind likely responsive by default but not documented as a goal. Third-party `zeroclaw-ui.com` desktop app exists. |
| **Known issues** | Web dashboard 404 not reported. Active refactoring (#806, "Refactoring now" label). Config changes require gateway restart. | Dashboard 404 regression in v0.1.9a (#3386, fixed in #3408 - build system was not auto-building web/dist). WebSocket auth parity fix needed (#2169, #2343, fixed). |

### Web UI detail

PicoClaw's web UI is architecturally separate from the agent. The `picoclaw-launcher` binary supervises the `picoclaw gateway` process, provides a React-based configuration UI on port 18800, and proxies WebSocket chat to the gateway's Pico channel. This separation means the gateway can run headless without web dependencies, which is the correct mode for a systemd-nspawn server deployment. The launcher adds a system tray icon on desktop Linux and Windows. For headless use, the Bubble Tea TUI launcher provides equivalent model/channel management from a terminal. The web UI cannot yet display token consumption or cost data (#2217, open), has no memory browser, and has no cron/heartbeat management interface. Configuration editing works but requires a gateway restart to apply changes.

ZeroClaw's web UI is embedded in the gateway and starts automatically. It provides operational dashboards that PicoClaw lacks: memory browsing, cost tracking, cron management, tool inspection, and doctor diagnostics. The cross-channel dashboard (#4519, shipped) shows channel health status across all configured integrations. The config editor can save changes, and some settings (routing, reliability) apply without restart via hot-reload. The pairing-based auth is adequate for single-user deployments behind a tunnel, the bearer token survives gateway restarts. The dashboard had a build regression in v0.1.9a where `web/dist` assets were not auto-built (#3386), fixed by #3408 adding an automatic frontend build step.

### Cloudflare Tunnel integration

ZeroClaw has first-class Cloudflare Tunnel support. The `[tunnel]` config section accepts `provider = "cloudflare"` with a `[tunnel.cloudflare]` block for the cloudflared token. The gateway spawns `cloudflared tunnel run` as a child process, parses the assigned URL from stderr, logs it for webhook configuration, and health-checks the child PID. The gateway's bind-address guard enforces that `0.0.0.0` binding requires either an active tunnel or explicit `allow_public_bind = true`, preventing accidental exposure. The `trust_forwarded_headers` setting (default false) should be enabled when behind cloudflared so that rate limiting and logging use the real client IP. ZeroClaw also supports Tailscale (`serve` and `funnel` modes), ngrok, Pinggy, OpenVPN, and custom tunnels through the same abstraction layer (`src/tunnel/mod.rs`).

PicoClaw has no tunnel integration. The gateway binds to `127.0.0.1:18790` by default, and can be set to `0.0.0.0` without any guard or warning. Exposing the gateway via a Cloudflare Tunnel requires running `cloudflared` externally (systemd service, Docker sidecar, or NixOS module) and pointing it at `http://127.0.0.1:18790`. This works but is entirely manual wiring with no coordination between the agent and tunnel processes.

For webhook delivery from external services (WhatsApp Cloud API, LINE), a tunnel provides the HTTPS endpoint these platforms require. Both projects handle inbound webhooks on the gateway port. ZeroClaw's managed tunnel means the gateway knows its own public URL and can log it for webhook registration. PicoClaw requires the operator to know the URL and configure it manually in the platform's webhook settings.

Telegram and Discord do not benefit from a tunnel in either project - both use outbound long polling/WebSocket connections that work from behind NAT without inbound ports. The tunnel matters only for platforms that push webhooks inbound (WhatsApp, LINE, Slack Events API, Nextcloud Talk).

### Security implications of tunnel exposure

Exposing ZeroClaw's gateway via Cloudflare Tunnel is reasonably safe given the defaults: pairing required, bearer token on API endpoints, rate limiting, security response headers, and the gateway's refusal to bind publicly without a tunnel or explicit override. The main risk is that the web dashboard (chat, config editor, memory browser) becomes accessible to anyone who can reach the tunnel URL and has a valid bearer token. Cloudflare Access policies add a second authentication layer at the edge, which is the recommended production pattern (the OpenClaw ecosystem has a Cloudflare Access JWT verification plugin that demonstrates this approach).

Exposing PicoClaw's gateway is riskier. The gateway HTTP endpoints have no authentication layer (#101 comments note this gap). The launcher has token auth but is a separate process and port. Channel-level `allow_from` restricts who can send messages but does not protect the HTTP API surface. If the gateway is exposed via a tunnel, any client can POST to webhook endpoints. For this deployment, the systemd-nspawn container's `privateNetwork = true` already restricts gateway access to the host, so the exposure surface is the tunnel configuration on the host, not the agent's own security.

### Practical assessment for this deployment

The web UI is not a primary interface for this deployment - Telegram and Discord are. The dashboard's value is operational: checking agent health, reviewing cost, browsing memory, and editing config without SSH. ZeroClaw's embedded dashboard delivers this without running a second process. PicoClaw's launcher would need to run alongside the gateway inside the container, adding a second long-lived process and port.

The Cloudflare Tunnel integration tips further toward ZeroClaw for deployments that need WhatsApp or LINE webhooks. For this deployment's current scope (Telegram + Discord, both outbound polling), a tunnel is not required for messaging. It would be useful only for remote dashboard access, and Tailscale already provides that without Cloudflare. If WhatsApp or LINE channels are added later, ZeroClaw's managed tunnel avoids the manual `cloudflared` wiring that PicoClaw would require.

The combination of ZeroClaw's embedded dashboard, pairing auth, managed tunnel support, and bind-address safety guard makes it the better fit for a headless server deployment that may later need external webhook ingress. PicoClaw's web UI is designed for desktop/local use and would need significant additional infrastructure (external cloudflared, authentication proxy) to serve the same role.

## Threaded Chat

Both projects now support Telegram forum topics with per-topic session isolation, but PicoClaw shipped it later and ZeroClaw's implementation is more mature. Neither project supports Discord thread-scoped conversations - Discord sessions are keyed per-sender per-channel with no thread isolation.

### Comparison Table

| Capability | PicoClaw | ZeroClaw |
|---|---|---|
| **Telegram forum topics (session isolation)** | Yes, since v0.2.1 (Mar 2026). PR #1291 adds `message_thread_id` handling; session keys use `chatId:topicId`. Fix #1330 sanitises slash characters in forum topic session keys. Feature request #1270 drove the work. | Yes, since late Feb 2026. Issue #1532 (closed as completed), PR #1548 populates `thread_ts` for forum groups. `conversation_history_key` and `conversation_memory_key` in `src/channels/mod.rs` include `thread_ts` when present. Distinguishes forum groups (`is_forum`) from regular groups so reply threads in non-forum groups do not split sessions. |
| **Telegram per-topic agent/model routing** | Proposed in #1270 (`topicAgentOverrides` config, inspired by OpenClaw) but not yet implemented. | Not implemented. #5225 (open, Apr 2026) requests `topic_id` routing for cron/delivery but no per-topic agent override. |
| **Telegram reply-to-message** | Bot replies land in the correct topic via `reply_to_message_id`. Issue #1328 proposes structured delivery metadata (`reply_to_message_id`, `suppress_text_reply`, `emoji_reaction`) so the model can target a specific message, but this is not yet merged. | Bot sets `reply_to_message_id` on outgoing messages (see `channel_delivery_instructions` and send payload in `src/channels/telegram.rs`). Reply routing to the correct topic works because `reply_target` encodes `chat_id:thread_id`. No explicit per-message targeting by the model. |
| **Discord thread isolation** | No. Sessions are keyed by `channelType:chatID` (e.g. `discord:123456`). No `thread_ts` or thread ID in the session key. Discord reply context (quoted message content) was added in #1047/#1048, but this is display context, not session isolation. | No. Discord adapter sets `thread_ts = None` (`src/channels/discord.rs:1175`), so thread ID never factors into history keys. Sessions are `discord_{sender}`. OpenClaw (upstream) has `threadSessionSuffix` config (#22951) but ZeroClaw has not ported it. |
| **Discord forum channels** | No support documented or requested. | No support documented. OpenClaw fixed forum channel thread creation (#7925/#10062) but ZeroClaw has not ported this. |
| **Memory scoping per thread** | Forum topic ID is included in session file paths (after #1291 + #1330 sanitisation fix). No Discord thread scoping. | Forum topic ID is included in both `conversation_history_key` and `conversation_memory_key` (runtime memory recall scoped per topic, #2254). No Discord thread scoping. |

### Telegram threads

ZeroClaw landed per-topic session isolation earlier (Feb 2026 via #1532/#1548) and with a cleaner design: it checks Telegram's `is_forum` flag to distinguish real forum topics from reply threads in regular groups, avoiding accidental session splitting. PicoClaw followed in v0.2.1 (Mar 2026, #1291) with a similar approach but needed a follow-up fix (#1330) for slash characters in forum topic session keys, and a separate guard (#1291 commit `320fcd1`) to ensure only forum topic threads get session isolation, not regular group reply threads. Both projects correctly route bot responses back to the originating topic via `reply_to_message_id`. Neither project yet supports per-topic agent or model overrides, though both have open feature requests for this.

For Telegram's lightweight reply-to-message threading (quoting a specific message rather than posting to the channel), both projects set `reply_to_message_id` on outgoing messages so the bot's response visually threads back to the triggering message. PicoClaw has an open proposal (#1328) for richer reply targeting - letting the model choose to reply to a specific message ID, suppress the text reply, or react with an emoji instead - but this is not merged.

### Discord threads

Neither project isolates Discord thread conversations. Both key sessions by channel + sender, meaning all threads in a Discord channel share the same conversation context for a given user. This is a known limitation inherited from OpenClaw's original design (OpenClaw #10907 documents cross-thread contamination; #22951 adds a `threadSessionSuffix` config option, but neither fork has ported it). For this deployment, Discord thread isolation is a gap in both projects. If distinct thread contexts matter, the workaround is separate Discord channels rather than threads within a single channel.

## NixOS systemd-nspawn Viability

Both PicoClaw and ZeroClaw are viable inside NixOS declarative `containers.<name>` systemd-nspawn containers. Neither project has fundamental incompatibilities with nspawn, though ZeroClaw requires more careful configuration due to its layered sandbox system. PicoClaw is the simpler deployment: a single Go binary with no runtime dependencies, no internal sandbox layer to conflict with nspawn's namespace isolation, and a straightforward cron/heartbeat implementation that runs in-process. ZeroClaw is equally deployable but demands attention to sandbox backend selection - its Landlock backend has a known process-poisoning bug (#5153, open) and its systemd service generation has a forking bug (#5232, open) that is irrelevant when the NixOS container module manages the process directly.

### Comparison Table

| Concern | PicoClaw | ZeroClaw |
|---|---|---|
| **Static binary** | Go binary, statically linked by default when `CGO_ENABLED=0`. No glibc dependency. Drops into a minimal NixOS container with zero additional packages. | Rust binary, single static release build, no runtime dependencies. Same ease of deployment. |
| **Network access** | Works with `privateNetwork = true` + NAT. Ollama reachable at host-side veth IP. No special network requirements beyond outbound HTTP/S. | Identical network model. Gateway binds to `127.0.0.1` inside the container by default. Same NAT config suffices. |
| **Exec tool** | Spawns shell via Go `os/exec`. Requires bash and coreutils in the container (present in NixOS minimal profile). No OS-level sandbox - relies on nspawn's namespace isolation. | Spawns shell via `tokio::process::Command`. Same shell/coreutils requirement. Has its own sandbox layer - set `security.sandbox.backend = "none"` inside nspawn to avoid conflicts. |
| **Cron/heartbeat** | In-process Go goroutine. Jobs stored as flat files in workspace. No interaction with container systemd. | In-process Tokio async task. Jobs stored in SQLite. No interaction with container systemd. `zeroclaw service install` is irrelevant - NixOS container config defines the service directly. |
| **Filesystem isolation** | `restrict_to_workspace: true` composes cleanly with nspawn namespace isolation. No conflicts. | `workspace_only: true` composes cleanly when `sandbox.backend = "none"`. Additional sandbox backends can cause permission errors - use none. |
| **Known open issues** | No container-specific or nspawn-specific open issues. | **#5153** (open): Landlock poisons the daemon process after a shell tool call. Workaround: `backend = "none"`. **#5232** (open): `zeroclaw service install` generates incorrect unit type. Not relevant when NixOS manages the service. |

### Static Binary Deployment

Both binaries are genuinely static and self-contained. PicoClaw's Go build produces a static binary by default (no CGO). ZeroClaw's Rust release build is similarly static-linked. In a minimal NixOS nspawn container, neither binary needs `environment.systemPackages` beyond the base NixOS container profile. The binary can be placed in the container via a Nix derivation - packaged from source via `llm-agents.nix` - giving reproducibility and rollback via the Nix store.

### Network Configuration

The standard NixOS container networking pattern works without modification:

```nix
containers.agent = {
  privateNetwork = true;
  hostAddress = "192.168.100.10";
  localAddress = "192.168.100.11";
  config = { lib, ... }: {
    networking.useHostResolvConf = lib.mkForce false;
    services.resolved.enable = true;
    networking.firewall.enable = false;
  };
};
networking.nat = {
  enable = true;
  internalInterfaces = [ "ve-+" ];
  externalInterface = "eth0"; # adjust to host interface
};
```

The agent reaches Ollama at `192.168.100.10:11434`. Remote HTTP MCP servers, Anthropic API, and messaging platform APIs route through NAT. No `forwardPorts` needed unless the agent's web dashboard should be accessible from the host.

### Exec Tool Capabilities

NixOS nspawn containers run with a restricted capability set by default - no `CAP_SYS_ADMIN`, `CAP_NET_ADMIN`, or elevated capabilities unless explicitly granted. For agent exec tool usage this is a feature, not a limitation. For tasks requiring additional tools beyond the base profile (git, curl, jq), add them to `environment.systemPackages` in the container config.

### Sandbox Layer Interaction (ZeroClaw-specific)

ZeroClaw's sandbox auto-detection chain is: Landlock, Firejail, Bubblewrap, Seatbelt, Docker, Noop. Inside an nspawn container, Landlock will be detected as available (it is a kernel LSM) and selected automatically, triggering #5153. Bubblewrap and Firejail have their own complications in restricted containers. The correct configuration for nspawn deployment is explicit:

```toml
[security.sandbox]
backend = "none"
```

This disables ZeroClaw's own sandboxing and relies on nspawn's namespace isolation, which is the stronger boundary. The application-level `workspace_only` and `SecurityPolicy` path validation still apply.

### Cron and Heartbeat

Both projects implement scheduling as in-process loops, not via system crontab or systemd timers. Neither interacts with the container's systemd instance. Jobs persist to the workspace directory (PicoClaw: flat files; ZeroClaw: SQLite). No conflicts with the container's init system. ZeroClaw's scheduler has a `max_concurrent` setting (default 5) that caps parallel job execution.

### NixOS Container Module vs Raw nspawn

The NixOS `containers.<name>` module wraps `systemd-nspawn` with several advantages for this deployment:

- Lifecycle managed by host systemd via `--keep-unit`
- Clean shutdown via `--notify-ready=yes` and `--kill-signal=SIGRTMIN+3`
- The container has its own full NixOS config closure - workspace files declared via `environment.etc`, secrets injected via sops-nix `bindMounts`
- The agent's systemd service is defined inside the container's NixOS config via `systemd.services`, bypassing both PicoClaw's launcher and ZeroClaw's `service install` command entirely
- The container shares the host's Nix store read-only; the agent binary lives in the store, giving rollback for free

### Blockers vs Manageable Risks

| Issue | Project | Blocker? | Mitigation |
|---|---|---|---|
| #5153 (Landlock poisons process) | ZeroClaw | No | Set `security.sandbox.backend = "none"` |
| #5232 (service unit forking) | ZeroClaw | No | NixOS manages the service unit directly |
| No nspawn-specific issues | PicoClaw | No | No action needed |

No genuine blockers exist for either project. ZeroClaw requires one explicit config line; PicoClaw requires no nspawn-specific configuration.

## Sources

- PicoClaw GitHub: https://github.com/sipeed/picoclaw (28k stars, MIT, Go)
- PicoClaw docs: https://docs.picoclaw.io/
- PicoClaw MCP config: https://docs.picoclaw.io/docs/configuration/tools/
- PicoClaw credential encryption: https://docs.picoclaw.io/docs/credential-encryption
- PicoClaw security audit issue: https://github.com/sipeed/picoclaw/issues/321
- PicoClaw credential leak bug: https://github.com/sipeed/picoclaw/issues/972
- PicoClaw sandbox hardening PR: https://github.com/sipeed/picoclaw/issues/331
- ZeroClaw GitHub: https://github.com/zeroclaw-labs/zeroclaw (30k stars, Apache-2.0, Rust)
- ZeroClaw wiki: https://github.com/zeroclaw-labs/zeroclaw/wiki
- ZeroClaw Mintlify docs (Telegram): https://mintlify.com/zeroclaw-labs/zeroclaw/api/channels/telegram
- ZeroClaw secret management wiki: https://github.com/zeroclaw-labs/zeroclaw/wiki/04.3-Secret-Management
- ZeroClaw security architecture: https://www.mintlify.com/zeroclaw-labs/zeroclaw/concepts/security
- Comparison (Wael Mansour): https://waelmansour.com/blog/ai-agent-frameworks-the-claw-ecosystem/
- Comparison (Shelldex): https://shelldex.com/compare/picoclaw-vs-zeroclaw/
- Comparison (Medium): https://medium.com/@phamduckhanh2411/picoclaw-vs-zeroclaw-vs-openclaw-which-lightweight-ai-agent-should-you-run-6fa87d4bce31
- PicoClaw memory system docs: https://sipeed-picoclaw-44.mintlify.app/features/memory
- PicoClaw workspace config: https://sipeed-picoclaw-44.mintlify.app/configuration/workspace
- PicoClaw session persistence (JSONL): https://github.com/sipeed/picoclaw/issues/711
- PicoClaw Seahorse short-term memory: https://docs.picoclaw.io/docs/changelog/ (v0.2.5 section)
- PicoClaw multi-user memory: https://github.com/sipeed/picoclaw/issues/995
- PicoClaw Engram integration request: https://github.com/sipeed/picoclaw/issues/175
- ZeroClaw memory backends wiki: https://github.com/zeroclaw-labs/zeroclaw/wiki/09.1-Memory-Backends
- ZeroClaw memory configuration: https://deepwiki.com/zeroclaw-labs/zeroclaw/3.5-memory-and-storage-configuration
- ZeroClaw memory system (DeepWiki): https://deepwiki.com/zeroclaw-labs/zeroclaw/8-memory-system
- ZeroClaw memory source (mod.rs): https://github.com/zeroclaw-labs/zeroclaw/blob/master/src/memory/mod.rs
- ZeroClaw snapshot/hydration: https://github.com/zeroclaw-labs/zeroclaw/blob/master/src/memory/snapshot.rs
- ZeroClaw auto-save snowball bug: https://github.com/zeroclaw-labs/zeroclaw/issues/4916
- ZeroClaw memory clear bug: https://github.com/zeroclaw-labs/zeroclaw/issues/5113
- ZeroClaw wildcard recall bug: https://github.com/zeroclaw-labs/zeroclaw/issues/5170
- ZeroClaw hybrid memory explainer: https://zeroclaws.io/blog/zeroclaw-hybrid-memory-sqlite-vector-fts5/
