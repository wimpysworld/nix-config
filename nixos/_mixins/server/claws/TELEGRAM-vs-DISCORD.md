# Telegram vs Discord for Agent Deployment

Last updated: 2026-04-11

## Recommendation

Telegram for the primary agent interface. Discord is not currently in use and was evaluated and set aside. Telegram wins on daily usability, long-polling simplicity behind NAT, voice note transcription maturity, and Martin's existing preference. The webhook gap (Discord's one advantage) is closable with lightweight bridges - a small bot that receives HTTP POSTs and calls `sendMessage`.

Discord is documented here for reference; it was evaluated against Telegram and rejected as a second platform for this deployment.

## Comparison Table

| Criterion | Telegram | Discord | Verdict |
|---|---|---|---|
| **Threading model** | Forum topics with `message_thread_id`, per-topic session isolation in ZeroClaw | Threads exist but per-thread session isolation is off by default, buggy in OpenClaw, not implemented in picoclaw/zeroclaw | Telegram wins |
| **Webhook/integration capability** | No native incoming webhooks. Requires a bridge bot or service (Webhookify, custom script) to receive external events. | Native incoming webhooks: generate a URL, paste into GitHub/Grafana/any service, messages appear in channel. Zero code required. | Discord wins |
| **Voice input** | Voice notes (OGG/Opus) transcribed by both picoclaw and zeroclaw via Whisper-compatible STT. Mature, well-tested. | Audio attachment transcription fixed in zeroclaw v0.1.8 (#2686/#2700). Picoclaw has voice channel support (`!vc join`). Less mature than Telegram path. | Telegram wins |
| **Long-polling support** | First-class. `getUpdates` with 25-30s timeout. No public endpoint needed. Both agents default to this mode. | Gateway WebSocket. No public endpoint needed. Both agents default to this mode. | Draw |
| **Bot setup complexity** | BotFather in-app, 60 seconds. One token. | Developer Portal web UI, OAuth2 URL generator, intent toggles. More steps. | Telegram wins |
| **Multi-agent coordination** | Forum supergroup with per-topic agent routing. Martin + both bots in one group, each topic bound to a different agent. | Multi-bot in one server works but thread isolation is broken across bot accounts (OpenClaw #49373). Neither picoclaw nor zeroclaw documents multi-bot Discord. | Telegram wins |
| **PicoClaw support quality** | Recommended channel in docs. Voice transcription via Groq Whisper. Forum topics requested (#1270) but not yet implemented. | Supported. Voice channel join/leave with ASR/TTS. No thread session isolation. | Telegram marginally ahead |
| **ZeroClaw support quality** | Long polling, voice transcription, `thread_ts` extracted from `message_thread_id`, per-topic conversation memory keying. | Gateway WebSocket, audio transcription fixed (#2700), no documented thread/forum session isolation. | Telegram ahead |

## Threading and Context Management

### Is threading important?

Threading matters less than expected. Both picoclaw and zeroclaw maintain per-agent memory systems (SeaHorse/SQLite and brain.db respectively) that persist facts across sessions regardless of which thread a message arrives in. Threading helps with two things: (1) keeping the conversation history clean so the agent's context window is not polluted by unrelated messages, and (2) giving the user a visual organisation model. For a single-user deployment, the first concern is minor since Martin is the only sender. The second is a quality-of-life improvement, not a requirement.

Threading becomes important if multiple agents share a single group. Without per-thread session isolation, all agents see all messages and may respond to prompts meant for a different agent.

### Telegram forum topics

Telegram supergroups with forum mode enabled create topics, each identified by a `message_thread_id`. This is the best threading model available for agent interactions:

- Each topic is visually distinct in the Telegram client, with its own message history.
- ZeroClaw extracts `message_thread_id` and keys conversation history as `chat_id:thread_id`, giving each topic isolated context. This is implemented and working in the current codebase (`src/channels/telegram.rs:1041-1091`).
- PicoClaw has an open feature request for forum topic support (#1270) with a contributed PR (#1291), but session key sanitisation bugs remain. The feature is not yet in a stable release.
- OpenClaw (for reference) has full per-topic agent routing: different topics in one group can route to different agents with isolated workspaces and memory (merged in #31513).

Practical setup: create a Telegram supergroup with forum mode enabled. Create topics for different concerns (general, coding, research, ops). With ZeroClaw, each topic gets its own conversation history automatically.

### Discord threads

Discord supports threads (temporary or persistent) and forum channels. The threading model has significant session isolation problems:

- The PICO-vs-ZERO comparison doc notes that Discord lacks per-thread session isolation in both projects.
- In OpenClaw, Discord thread isolation is off by default (`useSuffix: false` hardcoded). A PR to make it configurable (#22951) was closed as stale, with a reviewer noting it had a logic bug where inbound and outbound session keys would mismatch.
- Multi-bot thread ownership is broken: when two bots can see the same thread, the thread binding is account-scoped, so Bot B can steal messages meant for Bot A's bound subagent session (OpenClaw #49373).
- ZeroClaw's Discord channel does extract `thread_ts` from thread messages, but there is no documented per-thread session isolation configuration equivalent to Telegram's automatic topic keying.
- PicoClaw's Discord docs describe per-channel context but make no mention of per-thread isolation.

Discord forum channels (a channel type where every post is a thread) could theoretically work well, but neither picoclaw nor zeroclaw has forum-channel-aware session management.

### Verdict

Telegram forum topics provide better session isolation today, with ZeroClaw supporting it natively and PicoClaw close behind. Discord's thread model is structurally weaker for this use case due to default-off isolation and cross-bot leakage bugs.

## Webhooks and Integrations

### Telegram: no native incoming webhooks

Telegram has no equivalent of Discord's incoming webhook URL. You cannot generate a URL, paste it into GitHub, and have commits appear in a Telegram chat. Telegram's "webhook" concept is the reverse direction: Telegram pushes bot updates to your server. This requires a public HTTPS endpoint, which is irrelevant for this deployment (the agent uses long polling).

To get external events into Telegram, three options exist:

1. **Bridge bot/script**: A small service that exposes an HTTP endpoint, receives POSTs from external services, and calls the Telegram Bot API `sendMessage` method to relay the content into a specific chat or topic. Dozens of open-source implementations exist (e.g. `github-webhook-to-telegram`). This is ~50 lines of code or a pre-built container.

2. **Third-party relay service**: Webhookify, IFTTT, Zapier, or n8n can receive webhooks from any service and forward formatted messages to a Telegram bot. Webhookify specifically markets this as a core feature with AI-powered payload summaries. This adds a SaaS dependency.

3. **Grafana/GitHub native Telegram support**: Grafana has a built-in Telegram contact point (paste bot token + chat ID). GitHub does not have native Telegram integration, requiring option 1 or 2.

The bridge approach works but adds a moving part. The bot that receives the external webhook and the agent bot can be different bots (no conflict), and the messages land in the same group/topic where the agent can read and act on them.

### Discord: native incoming webhooks

Discord incoming webhooks are the simplest integration primitive available:

1. Go to channel settings, click Integrations, click Create Webhook.
2. Copy the URL.
3. Paste it into any service that supports webhook URLs.
4. External service POSTs JSON to the URL, message appears in the channel.

No bot required. No code. No public endpoint on your infrastructure. The webhook URL is hosted by Discord's servers. GitHub has native Discord webhook support (append `/github` to the URL). Grafana has a built-in Discord contact point. Uptime monitors, CI/CD pipelines, and any service that can fire HTTP POSTs can push into Discord with zero custom code.

Discord webhooks are one-way (inbound to Discord only). They cannot read messages, respond, or interact. But for the "external service sends event, agent reads it and acts" use case, the agent bot is already connected via the Gateway WebSocket and can see webhook-posted messages in the channel.

### Practical comparison for "external event to agent action"

**Discord path**: Create webhook URL in a `#alerts` channel. Paste URL into GitHub, Grafana, uptime monitor. Events appear in channel. Agent bot reads them via Gateway WebSocket and can act. Setup time: 5 minutes per service. No custom code. No infrastructure.

**Telegram path**: Deploy a bridge bot/container that exposes an HTTP endpoint. Configure GitHub/Grafana to POST to that endpoint. Bridge bot calls `sendMessage` to relay into the appropriate Telegram group topic. Agent bot reads the message and acts. Setup time: 30-60 minutes initial setup for the bridge, then 5 minutes per service. Requires running one additional small service.

For a NixOS deployment in systemd-nspawn with `privateNetwork = true`, the Discord webhook advantage is that the webhook URL is hosted by Discord, not by your infrastructure. The bridge bot for Telegram would need network access to receive external POSTs, which means either running it outside the container or configuring port forwarding.

### Verdict

Discord has a clear, material advantage for receiving external events. If webhook-based integrations are a priority, running Discord alongside Telegram (not instead of it) is justified.

## Voice Input

### Telegram voice notes

Telegram voice messages are OGG/Opus audio files sent inline in chat. Both agents support receiving and transcribing them:

**PicoClaw**: Voice transcription is a documented first-class feature. The default STT backend is Groq's hosted Whisper (`groq/whisper-large-v3`), configured via a `model_list` entry. The transcription echoes the text back to the user before the agent processes it (added in v0.2.2). Local Whisper endpoints (whisper.cpp, faster-whisper) work via the OpenAI-compatible API format. TTS replies (voice note responses) were requested (#1503, closed as implemented) with pluggable providers (OpenAI, ElevenLabs, Piper, Kokoro). PicoClaw docs list Telegram as "Recommended. Supports voice transcription with Groq."

**ZeroClaw**: Voice transcription is configured via the `[transcription]` config block with `provider = "openai"` (or `"deepgram"`). The Telegram channel downloads the audio via `getFile`, sends it to the configured STT endpoint, caches the result to avoid redundant API calls for forwarded messages, and injects the transcript as message text. Bug #3115 (voice messages ignored in Telegram) was fixed in v0.1.7. The `initial_prompt` parameter for improving proper noun recognition was added in #3640. Local Whisper servers (faster-whisper-server) are supported via the OpenAI-compatible endpoint.

### Discord voice

**PicoClaw**: Supports Discord voice channels via `!vc join`/`!vc leave` commands. The bot joins a voice channel, transcribes speech via the configured ASR model, processes it, and plays back TTS audio. This is a live voice conversation, not voice notes. Requires `voice.tts_model_name` in config.

**ZeroClaw**: Discord audio attachment transcription was broken until v0.1.8 (bug #2686, fixed in PR #2700). Audio attachments are now transcribed via the same `[transcription]` config. ZeroClaw does not have Discord voice channel join/listen capability. Voice messages (Discord's voice message feature, distinct from voice channels) are handled as audio attachments.

### Practical usability

Voice input via Telegram is genuinely useful for mobile-first interaction. Send a voice note while walking, get a text response. Latency depends on the STT backend:

- Groq hosted Whisper: ~1-2 seconds for a typical voice note (fast, but requires API key and sends audio to Groq's servers).
- Local faster-whisper on a GPU workstation: ~2-4 seconds for a 30-second note on an RTX 3090. Acceptable.
- Local Whisper on CPU: 10-30 seconds. Too slow for conversational use.

Accuracy is good for English with Whisper large-v3. Proper nouns are the main weakness, mitigated by ZeroClaw's `initial_prompt` feature.

Discord voice channel participation (PicoClaw only) is a different use case: real-time conversation rather than async voice notes. More demanding on infrastructure (requires continuous audio streaming and processing) and less practical for a personal assistant deployment.

### Verdict

Telegram voice notes are the practical choice for voice input. Both agents handle them well. Discord voice is either less mature (ZeroClaw) or a different paradigm (PicoClaw voice channels). For "send a voice note from your phone, agent transcribes and acts", Telegram is the clear winner.

## Platform Support in PicoClaw and ZeroClaw

### PicoClaw

| Feature | Telegram | Discord |
|---|---|---|
| Channel status | Recommended, first-class | Supported, easy setup |
| Voice transcription | Yes, Groq Whisper default, pluggable | Yes, ASR + voice channels |
| Forum/thread isolation | Not yet implemented (#1270, PR #1291 in progress) | Not implemented, no thread isolation |
| Group trigger control | `allow_from`, `mention_only` | `allow_from`, `mention_only`, prefix triggers |
| Streaming responses | Supported | Supported |
| Multi-agent routing | Not implemented (no forum topic routing) | Not documented |
| Known issues | Session key sanitisation bug with forum topics | None documented |

### ZeroClaw

| Feature | Telegram | Discord |
|---|---|---|
| Channel status | First-class, well-tested | Supported, Gateway WebSocket |
| Voice transcription | Yes, configurable STT provider, caching, `initial_prompt` | Yes, fixed in v0.1.8 (#2700), same STT config |
| Forum/thread isolation | `message_thread_id` extracted, per-topic conversation memory keying via `thread_ts` | `thread_ts` extracted but no documented per-thread session isolation config |
| Group trigger control | `allowed_users`, `mention_only`, pairing mode | `allowed_users`, `guild_id`, `mention_only` |
| Streaming responses | `stream_mode = "partial"` with edit throttle | Draft updates supported |
| Multi-agent routing | Not documented for zeroclaw (exists in OpenClaw) | Not documented |
| Known issues | Voice was briefly broken in early versions (#3115, fixed) | Transcription was broken until v0.1.8 (#2686, fixed) |

### Maturity assessment

Both agents treat Telegram as their primary/recommended channel. Documentation, examples, and community discussion centre on Telegram. Discord support works but receives less attention and has had more latent bugs (voice transcription not wired up until explicitly reported). ZeroClaw's Telegram implementation is more feature-complete than PicoClaw's (forum topic awareness vs an open feature request), reinforcing the recommendation from the PICO-vs-ZERO comparison.

## Platform Mechanics for This Deployment

### Long polling behind NAT

With `privateNetwork = true` in the systemd-nspawn container, the agent has outbound internet access but no inbound port. This is the correct topology for both platforms:

- **Telegram**: Long polling (`getUpdates`) is outbound-only. The agent calls Telegram's servers. No public endpoint needed. This is the default mode for both picoclaw and zeroclaw. Webhook mode (Telegram pushing to you) would require a public HTTPS endpoint, which is incompatible with this deployment. Long polling adds ~640ms median latency vs ~180ms for webhooks (benchmarked in 2025), which is negligible for a personal assistant.

- **Discord**: Gateway WebSocket is outbound-only. The agent connects to Discord's Gateway v10 via WebSocket. No inbound port needed. This is the default mode for both agents.

Neither platform requires a public endpoint for the core agent interaction. Discord's incoming webhooks for external services are also unaffected, as the webhook URL is hosted by Discord, not by the agent's infrastructure.

### Bot management

- **Telegram BotFather**: In-app, conversational. `/newbot`, name it, get a token. Token management is manual (BotFather can regenerate). Permissions are implicit (bots can read messages in groups they are added to, controlled by group privacy mode). Scoping is via `allow_from` user IDs in the agent config.

- **Discord Developer Portal**: Web-based. Create application, create bot, configure intents (Message Content Intent must be explicitly enabled), generate OAuth2 invite URL with permission scopes. More steps, more granular control. Token visible in the portal.

For a single-user personal agent, Telegram's simplicity wins. Discord's granular permissions matter more for community bots.

### Notification delivery

Both platforms deliver push notifications reliably to mobile clients. Telegram is marginally faster for personal messages (no gateway hop). Discord notifications can be noisier if the agent is in a server with other activity.

### Multi-agent in one group

Martin + picoclaw bot + zeroclaw bot (or two instances of the chosen agent) in a shared Telegram forum supergroup:

- Each bot is a separate BotFather bot with its own token.
- Each bot can be restricted to specific topics via `message_thread_id` routing (ZeroClaw) or `allow_from` (both).
- Bots do not see each other's messages in private/group mode unless explicitly configured.
- Forum topics provide visual separation: "Topic: Claw-A" and "Topic: Claw-B".

In Discord, multi-bot in one server works but the thread isolation bugs documented above (OpenClaw #49373, #10907) suggest caution. The agents might compete for the same messages in shared channels.

## Recommendation for This Deployment

**Primary interface: Telegram.** Use a forum-enabled supergroup with topics for different concerns. ZeroClaw's `message_thread_id` handling gives per-topic conversation isolation out of the box. Voice notes work well for mobile interaction. Long polling is the correct mode for a containerised deployment behind NAT. Setup is trivial.

**Discord**: Evaluated and set aside. Telegram covers all interaction needs. Webhook integrations from external services will use a lightweight HTTP-to-Telegram bridge rather than a separate Discord server.

**Voice input: Telegram voice notes.** Configure Whisper STT (Groq for convenience, local faster-whisper for privacy). Both picoclaw and zeroclaw handle this well.

**What to skip**: Discord voice channels (PicoClaw's `!vc join` feature) are unnecessary for a personal assistant. Telegram webhook mode (as opposed to long polling) is unnecessary and incompatible with the NAT-ed container topology.

## Multi-Agent Conversation

> The notes below document Telegram and Discord multi-agent patterns for future reference, when Skrye and Zannah are activated as subordinate agents. The current deployment is a single active agent (Traya) running as master/padawan instances; multi-agent patterns do not apply yet.

Solo conversations work today on both platforms with minimal configuration. Group conversations where both agents participate in the same thread are possible on Discord but blocked on Telegram by a fundamental Bot API limitation: bots cannot see messages from other bots. Agent-to-agent communication across zeroclaw instances has no production-ready path today, though A2A protocol support is in active development (zeroclaw #3566).

### Telegram: Solo Conversations

Solo conversation is the simplest pattern and works out of the box. Each zeroclaw instance runs as a separate process with its own bot token, config directory, and memory database.

**Private DMs (fully isolated).** Martin messages `@TrayaSithbot` in a private chat. No configuration beyond the standard channel setup is needed:

```toml
# master: ~/.zeroclaw/config.toml
[channels_config.telegram]
bot_token = "MASTER_BOT_TOKEN"
allowed_users = ["MARTIN_USER_ID"]
mention_only = false
```

```toml
# padawan: ~/.zeroclaw/config.toml
[channels_config.telegram]
bot_token = "PADAWAN_BOT_TOKEN"
allowed_users = ["MARTIN_USER_ID"]
mention_only = false
```

Each instance has its own `memory.db`, conversation history, and workspace. Context is fully isolated. This is the recommended default for most interactions.

**Forum supergroup with instance-specific topics.** Create a Telegram supergroup with forum mode enabled. Create a "Master" topic and a "Padawan" topic. Both bots are members of the group, but each responds only when addressed in its topic. ZeroClaw keys conversation history as `chat_id:thread_id`, so each topic gets isolated context automatically (implemented in `src/channels/telegram.rs`).

With `mention_only = true`, Martin types `@TrayaSithbot what is the status of X?` in any topic, and only the addressed instance responds:

```toml
# Both instances: set mention_only for group contexts
[channels_config.telegram]
bot_token = "RESPECTIVE_BOT_TOKEN"
allowed_users = ["MARTIN_USER_ID"]
mention_only = true
```

### Telegram: Group Conversations

Group conversation where both bots participate in the same thread faces a hard platform constraint.

**The bot-to-bot wall.** Telegram's Bot API does not deliver messages sent by bots to other bots, regardless of privacy mode, admin status, or any configuration. From Telegram's FAQ: "bots will not be able to see messages from other bots regardless of mode." This is enforced server-side and cannot be overridden. OpenClaw #408 documents this limitation and its impact.

Concretely: Martin sends a message in a shared group. Both @SkryeSithbot and @ZannahSithbot can see Martin's message and respond. But @SkryeSithbot's response is invisible to @ZannahSithbot, and vice versa. There is no configuration in zeroclaw, picoclaw, or any Bot API framework that changes this. The bots cannot have a conversation with each other, cannot build on each other's responses, and cannot coordinate through the Telegram chat.

**What works.** Martin can trigger both bots to respond to the same message by @-mentioning both: `@SkryeSithbot @ZannahSithbot what do you think about X?`. Both bots independently generate a response to Martin's message. Each sees only Martin's text, not the other bot's reply. This is parallel execution, not a conversation. There is no round-robin, no "respond to what the other bot said", and no arbitration.

**Bot storm prevention.** With `mention_only = true` on both instances, storms are impossible. Without it, both bots would respond to every human message in the group, which is noisy but not recursive (bot messages are invisible to other bots, so there is no feedback loop). The risk is wasted API calls and cluttered chat, not an infinite loop.

**Workarounds for true bot-to-bot exchange on Telegram:**

1. **Out-of-band relay.** Have both zeroclaw instances share a common datastore (file, SQLite, Redis) and poll it. Bot A writes its response to the shared store. Bot B reads it on next turn. This works but is custom engineering outside zeroclaw's scope.
2. **MTProto userbot.** Run one agent as a Telegram user account (not a bot) via the MTProto client API. User accounts can see all messages including bot messages. This violates Telegram's ToS for automated accounts and risks bans. Not recommended.
3. **Use Discord instead.** Discord does not have the bot-to-bot visibility restriction. If group conversations between both agents are important, run that specific interaction on Discord.

OpenClaw #24633 requests an `allowBots` config option for Telegram, mirroring the Slack implementation. Even if implemented, it cannot overcome the Bot API's server-side filtering. The issue acknowledges this: "Telegram's own FAQ confirms bots can't see other bots via Bot API."

### Discord: Solo Conversations

Discord provides stronger isolation primitives than Telegram for solo conversations.

**Private DMs.** Martin DMs `@TrayaMasterBot` directly. Identical to Telegram DMs: fully isolated, no configuration beyond the standard channel setup. ZeroClaw's Discord channel automatically processes DMs regardless of `guild_id` or `mention_only` settings (DMs bypass both filters in the code).

```toml
# master: ~/.zeroclaw/config.toml
[channels_config.discord]
bot_token = "MASTER_DISCORD_BOT_TOKEN"
guild_id = "SHARED_SERVER_ID"
allowed_users = ["MARTIN_DISCORD_USER_ID"]
listen_to_bots = false
mention_only = false
```

**Channel-based isolation.** Create a `#master` channel and a `#padawan` channel in the Discord server. Use Discord's channel permissions to grant each bot access only to its own channel. This is enforced at the platform level - no zeroclaw configuration required beyond the standard setup.

### Discord: Group Conversations

Discord does not share Telegram's bot-to-bot restriction. Bots can see messages from other bots by default. ZeroClaw's Discord channel has a `listen_to_bots` flag that controls this:

```toml
# To enable bot-to-bot visibility:
[channels_config.discord]
bot_token = "RESPECTIVE_BOT_TOKEN"
guild_id = "SHARED_SERVER_ID"
allowed_users = ["MARTIN_DISCORD_USER_ID"]
listen_to_bots = true
mention_only = true
```

**Bot storm risk.** With `listen_to_bots = true` and `mention_only = false`, both bots respond to everything including each other, creating a feedback loop until rate limits intervene. Keep `mention_only = true` to prevent this; Martin controls turn-taking by explicitly @-mentioning the bot they want to respond.

| Setting | Safe default | Storm risk |
|---|---|---|
| `mention_only = true` (both platforms) | Yes | None. Bots only respond when @-mentioned. |
| `listen_to_bots = false` (Discord) | Yes | None. Bots ignore each other entirely. |
| `listen_to_bots = true` + `mention_only = true` | Moderate | Low. Bots see each other but only respond if @-mentioned. Martin controls turns. |
| `listen_to_bots = true` + `mention_only = false` | No | High. Both bots respond to everything including each other. Feedback loop until rate limit. |
| `allowed_users` restricted to Martin only | Yes | None. Bot user IDs are not in the allowlist. |

### Agent-to-Agent Communication

ZeroClaw's multi-agent capabilities are currently intra-instance only. The `delegate` tool (in `src/tools/delegate.rs`) allows a primary agent to hand off subtasks to specialised sub-agents, but these sub-agents live inside the same process, share the same runtime, and are configured in `[agents.*]` blocks:

```toml
# Sub-agent within the same zeroclaw instance
[agents.researcher]
provider = "ollama"
model = "llama3"
system_prompt = "You are a research assistant."
temperature = 0.3
max_depth = 3
agentic = true
allowed_tools = ["web_search", "knowledge"]
```

**What does not exist today:**

- No built-in mechanism for two separate zeroclaw instances to exchange messages directly.
- No way for one agent to invoke another as a tool or service.
- No shared memory or context synchronisation between instances.
- The `swarm` config key exists in the schema but documentation is sparse and it appears to be for intra-instance orchestration, not cross-host communication.

**A2A protocol support (zeroclaw #3566, open, PR #4166 submitted).** The proposal adds an `A2ATool` and `A2AServer` for cross-instance communication via HTTP JSON-RPC with bearer token authentication. Not merged as of April 2026. Cross-instance agent communication is aspirational, not operational.

### Recommended Setup

> The steps below describe running two zeroclaw instances (master and padawan) with Telegram as the primary interface. Discord steps are included for reference only - Discord is not in active use for this deployment.

Concrete steps for running master (on the home office host) and padawan (on the remote host) with zeroclaw.

**Step 1: Create the Telegram bots.**

- Message @BotFather on Telegram. Create `@TrayaSithbot` (one bot account for the Traya identity; master and padawan share the identity but use separate tokens). Record both tokens.
- For each bot: `/setprivacy` then `Disable` (allows the bot to see all group messages, not just commands). Note: this must be done before adding the bot to a group to take effect.
- For each bot: `/setjoingroups` then `Enable`.

**Step 2: Create the Telegram supergroup.**

- Create a new Telegram group. Upgrade it to a supergroup (happens automatically when enabling topics).
- Enable Topics (forum mode) in group settings.
- Create topics: "General", "Master", "Padawan" (or whatever naming scheme suits).
- Add both bots to the group.

**Step 3: Configure each zeroclaw instance for Telegram.**

```toml
# master: ~/.zeroclaw/config.toml
[channels_config.telegram]
bot_token = "${env:MASTER_TG_TOKEN}"
allowed_users = ["MARTIN_TG_USER_ID"]
mention_only = true
stream_mode = "partial"
draft_update_interval_ms = 1000
```

```toml
# padawan: ~/.zeroclaw/config.toml
[channels_config.telegram]
bot_token = "${env:PADAWAN_TG_TOKEN}"
allowed_users = ["MARTIN_TG_USER_ID"]
mention_only = true
stream_mode = "partial"
draft_update_interval_ms = 1000
```

With `mention_only = true`, Martin addresses `@TrayaSithbot` (master) or the padawan bot in any topic. Only the addressed instance responds.

**Summary of what works today vs what is aspirational (for future multi-agent use):**

| Capability | Telegram | Discord |
|---|---|---|
| Solo DM conversation | Works | Works |
| Solo topic/channel isolation | Works (forum topics + mention_only) | Works (channel permissions) |
| Both instances respond to same message | Works (both see Martin's @-mention) | Works |
| Instance A sees Instance B's response | Blocked (Telegram Bot API limitation) | Works (listen_to_bots = true) |
| Moderated round-table | Not possible | Works with mention_only gating |
| Automatic agent-to-agent exchange | Not possible | Dangerous without careful gating |
| Cross-instance delegation (A2A) | Not implemented (zeroclaw #3566) | Not implemented |

## Alternative Platforms

Telegram + Discord remains the right answer. No alternative platform offers a compelling reason to replace either for this deployment. Several platforms are worth understanding, because both picoclaw and zeroclaw support them, but none changes the core recommendation.

### Matrix

The strongest alternative to Telegram on paper: federated, self-hostable, E2EE, and supported by both projects. PicoClaw's Matrix channel (merged via #789) supports text, media, typing indicators, placeholders, group triggers, audio transcription, and E2EE. ZeroClaw's Matrix channel uses matrix-sdk with sync-based event streaming, E2EE, draft edits, and room alias resolution. Both use outbound sync (no public endpoint needed). The problem is client quality. Element X on mobile is improving but still lacks features that Telegram has had for years: search is absent or broken, notification reliability is inconsistent, and the community consensus as of early 2026 is that no Matrix client matches Telegram as a daily driver. SchildiChat is the closest for users coming from Telegram, but it is a fork with a smaller team. For a personal agent interface where you want to fire off a voice note while walking and get a reply seconds later, Telegram's client polish matters. Matrix would make sense if federation or self-hosting the server were hard requirements, but for a single-user deployment talking to cloud LLM APIs, that advantage is moot.

### Slack

Supported by both projects with Socket Mode (outbound WebSocket, no public endpoint). PicoClaw's Slack channel (PR #34, merged) has thread support, reactions, slash commands, and typing indicators. ZeroClaw's Slack channel uses REST polling with bot token auth. Slack's webhook and integration ecosystem is mature, arguably richer than Discord's, with native support from nearly every developer tool. The dealbreaker is the free plan: 90-day message history, 3-app limit (recently reduced from 10), and the workspace model assumes a team, not a single user. Paying 7-8 GBP/month for a solo agent chat is hard to justify when Telegram and Discord are free. If you already had a paid Slack workspace, running the agent there alongside your work channels would be a strong option. Starting one from scratch for this purpose is not.

### Mattermost

Self-hostable, webhook-compatible (Slack-format webhooks work directly), and free for up to 100 users on the new Entry tier. ZeroClaw has a mature Mattermost channel with polling, thread support, typing indicators, and mention-only mode. PicoClaw has an open feature request (#1587, low priority) with a contributed PR (#1586) but no stable release yet. Mattermost gives you Discord-style incoming webhooks plus full data sovereignty, which is appealing. The catch: you must run a Mattermost server, which means PostgreSQL, an application server, and ongoing maintenance. For a deployment already running systemd-nspawn containers, this is not outrageous, but it is a meaningful step up from "paste a bot token and go." The mobile apps are adequate but not a daily driver in the way Telegram is. Mattermost is the strongest candidate if you want to consolidate Telegram + Discord into a single self-hosted platform and are willing to accept worse mobile UX.

### Signal

Supported by both projects via signal-cli as a bridge. ZeroClaw's Signal channel uses HTTP to a local signal-cli instance. PicoClaw's Signal channel (#41, closed as completed) follows the same pattern. Signal's E2EE is best-in-class, but the bot experience is poor: no official bot API, a dedicated phone number is required, no threading model, no webhooks, risk of rate-limiting or bans for bot-like behaviour, and the signal-cli bridge adds a JVM dependency or Docker container. Voice notes work but the overall agent UX is far behind Telegram. Only worth considering if end-to-end encryption of agent conversations is a hard requirement, which it is not for a deployment calling cloud LLM APIs over HTTPS.

### Others considered and dismissed

**WhatsApp**: Supported by both projects, but the Cloud API requires a Meta Business account and a public HTTPS callback endpoint, which is incompatible with the NAT-ed container topology. PicoClaw's native whatsmeow mode avoids this but uses an unofficial client library that risks account bans. Not suitable. **iMessage**: ZeroClaw only, macOS only, local AppleScript integration. Irrelevant for NixOS. **IRC**: ZeroClaw supports it. No voice, no media, no webhooks, no mobile push. A nostalgia pick, not a practical one. **Nextcloud Talk**: ZeroClaw supports it but requires a public HTTPS callback endpoint. Incompatible with this deployment. **XMPP**: Neither project supports it. **Zulip**: Neither project supports it, despite its excellent topic-threaded model. **Rocket.Chat**: Neither project supports it. **Nostr**: ZeroClaw supports it via relay WebSocket. Interesting for a decentralised future but no practical advantage today: negligible userbase, no voice notes, immature clients.

### Verdict

Telegram is the right choice for this deployment. No alternative platform offers a better combination of daily-driver client quality, voice input, long-polling behind NAT, and agent framework maturity. Discord was evaluated and set aside; the webhook advantage is closable with a lightweight bridge. Matrix is the closest contender but fails on client polish.

## Sources

### Platform documentation
- Telegram Bot API: voice message transcription (`core.telegram.org/api/transcribe`)
- Telegram Bot API: long polling vs webhook (`gramio.dev/updates/webhook`)
- Discord webhooks: incoming and event webhooks (`docs.discord.com/developers/platform/webhooks`)
- Discord webhook setup guide (`support.discord.com/hc/en-us/articles/228383668`)

### PicoClaw
- Telegram channel docs (`docs.picoclaw.io/docs/channels/telegram`)
- Discord channel docs (`docs.picoclaw.io/docs/channels/discord`)
- Voice transcription: pluggable speech I/O providers (#1503, closed as implemented)
- Forum topics feature request (#1270, open, PR #1291 in progress)
- Chat apps overview (`github.com/sipeed/picoclaw/blob/main/docs/chat-apps.md`)
- Changelog with v0.2.2 voice transcription (`docs.picoclaw.io/docs/changelog`)

### ZeroClaw
- Telegram channel reference (`mintlify.com/zeroclaw-labs/zeroclaw/api/channels/telegram`)
- Discord channel reference (`mintlify.com/zeroclaw-labs/zeroclaw/api/channels/discord`)
- Channels reference (`github.com/zeroclaw-labs/zeroclaw/blob/master/docs/reference/api/channels-reference.md`)
- Discord transcription bug (#2686, fixed in PR #2700)
- Telegram voice bug (#3115, fixed in PR #3127)
- Transcription initial_prompt (#2881, closed as implemented in #3640)
- Multi-channel setup guide (`zeroclaws.io/blog/zeroclaw-multichannel-telegram-discord-whatsapp-setup`)
- Platform webhook integrations (`deepwiki.com/zeroclaw-labs/zeroclaw/10.4-platform-webhook-integrations`)
- Channel system overview (`mintlify.com/zeroclaw-labs/zeroclaw/concepts/channels`)

### OpenClaw (reference for threading patterns)
- Per-topic agent routing (#31473, merged in #31513/#33647)
- Telegram forum topic support (#6597, implemented)
- Discord thread session isolation (#22951, closed as stale with logic bug)
- Discord thread contamination (#10907, closed as stale)
- Discord thread-bound subagent isolation (#49373, open)
- Per-channel sessions for Discord (#32601, open)
- Shared sessions across channels (#19929, open)

### Webhook integration examples
- GitHub to Discord webhook (`gist.github.com/jagrosh/5b1761213e33fc5b54ec7f6379034a22`)
- Grafana OnCall to Discord (`grafana.com/blog/2024/05/20/grafana-oncall-connect-to-discord-mattermost-and-more-with-webhooks`)
- Grafana to Telegram (`grafana.com/docs/grafana/latest/alerting/configure-notifications/manage-contact-points/integrations/configure-telegram`)
- GitHub webhook to Telegram bridge (`github.com/dashezup/github-webhook-to-telegram`)
- Webhookify relay service (`webhookify.app/integrations/telegram-webhook-notifications`)

### Multi-agent patterns
- Telegram Bot FAQ: bots cannot see other bots' messages (`core.telegram.org/bots/faq`)
- Telegram Bot Features: privacy mode (`core.telegram.org/bots/features#privacy-mode`)
- OpenClaw: bots can't read other bots on Telegram (#408, closed with documentation)
- OpenClaw: allowBots config for Telegram (#24633, open)
- OpenClaw: ignoreOtherMentions for Discord multi-bot (#23689, merged)
- OpenClaw: requireMention broken in multi-account Discord (#45300)
- OpenClaw: multi-agent routing guide (`coclaw.com/guides/openclaw-multi-agent-routing`)
- PicoClaw: multi-bot group chats storm prevention (#1589, documented workaround: mention_only)
- PicoClaw: agent routing and bindings (`deepwiki.com/sipeed/picoclaw/7.5-agent-routing-and-bindings`)
- PicoClaw: multi-user support and session isolation (#995, closed)
- ZeroClaw: mention_only bug with non-text messages (#1662, fixed)
- ZeroClaw: Telegram supergroup topic support for delivery routing (#5225, open)
- ZeroClaw: delegate tool and sub-agents (`deepwiki.com/zeroclaw-labs/zeroclaw/12.7-delegate-agents-and-sub-agents`)
- ZeroClaw: A2A protocol support (#3566, open, PR #4166 submitted)
- ZeroClaw: agent teams/subagents orchestration (#2419, #2527, both closed as implemented)
- ZeroClaw: agentic delegate mode (#1047, closed as implemented in PR #1085)
- ZeroClaw: Discord channel listen_to_bots flag (`mintlify.com/zeroclaw-labs/zeroclaw/api/channels/discord`)
- ZeroClaw: config schema with delegate agents and swarms (`github.com/zeroclaw-labs/zeroclaw/blob/master/src/config/schema.rs`)

### Benchmarks and comparisons
- Telegram webhook vs long-polling latency benchmarks (`pcg-telegram.com/blogs/936816045`)
- Telegram rate limits and polling vs webhook decision tree (`fyw-telegram.com/blogs/1650734730`)
- Voice-first agent control via Telegram evaluation (`youtube.com/watch?v=gunCOpgjAPs`)
