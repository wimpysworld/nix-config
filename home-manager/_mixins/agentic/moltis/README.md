# Moltis projection

The assistants consumer projects agents, skills, and global instructions into `~/.moltis` for Moltis (tag 20261023.01). The shared gate requires user `martin`, Linux or Darwin, and host tag `moltis`: `skrye`, `zannah`, and `traya`. Traya replaces Malak as a Moltis host. Malak hosts the [private Matrix server](../../../../nixos/_mixins/server/private-matrix/README.md).

The owned-files deployer tracks `~/.moltis` as an ownership root. Personal, command-derived, sops-rendered secret, and Chainguard skills deploy there as regular files.

> [!IMPORTANT]
> This change prepares configuration only. Do not activate services, create accounts, change DNS, write secrets, or sign in without separate approval.

## Traya on Darwin

Traya uses the ChatGPT subscription through `openai-codex::gpt-6.1-sol@reasoning-medium` for Telegram and Matrix chat, heartbeat, and `coordinator` (`reasoning_effort = "medium"`), and `openai-codex::gpt-6-astra@reasoning-medium` for the `review` preset and GitHub companion code-review turns (`reasoning_effort = "medium"`). The `auxiliary` and `compression` presets use `openai-codex::gpt-6.1-luna@reasoning-high` with `reasoning_effort = "high"`. Title generation uses the same Luna model with high effort through Moltis's `@reasoning-high` model suffix, independently of presets.

The `auxiliary.compaction` and `auxiliary.vision` settings also select Luna with high effort, but Moltis 20261023.01 does not connect those settings to callers. Structured compaction still uses the session provider. The [pinned provider registry](https://github.com/moltis-org/moltis/blob/20261023.01/crates/providers/src/registry/registration.rs) applies reasoning suffixes when it resolves models.

The installed Codex catalogue confirms `gpt-6.1-sol`, `gpt-6-astra`, `gpt-6.1-luna`, and their reasoning effort suffixes. Live availability under the subscription remains unverified. No API-key billing fallback is configured.

After approval and deployment, sign in locally on Traya as the same user that runs Moltis:

```sh
moltis auth login --provider openai-codex
```

Alternatively, connect OpenAI Codex in the Moltis settings UI. [Upstream provider documentation](https://github.com/moltis-org/moltis/blob/20261023.01/docs/src/providers.md) describes OAuth sign-in. OAuth credentials are unmanaged runtime state, not Nix configuration or SOPS secrets. Do not copy tokens into this repository.

Gemini still supplies text-to-speech and speech-to-text. Traya therefore still requires `GEMINI_API_KEY`, although the Gemini chat provider is disabled. Traya retains `TELEGRAM_BOT_TRAYA` and `SOUL_TRAYA` from `secrets/moltis.yaml`.

Traya uses the logged-in user's LaunchAgents, labelled `org.moltis.gateway` and `org.moltis.llama-swap`. `org.moltis.llama-swap` pre-seeds `Qwen/Qwen3-Embedding-0.6B-GGUF:Q8_0` under `${XDG_STATE_HOME}/moltis/llama-models/huggingface` and serves `qwen3-embedding-0.6b` on `127.0.0.1:8080`. Both LaunchAgents start at login and restart on failure. Neither service is a boot daemon. An always-on Mac still needs a user login and readable sops-nix secrets. The wrapper waits briefly for secrets and fails if they remain unavailable.

On Darwin, Home Manager also restarts Moltis after synchronous SOPS rendering and owned assistant deployment when its public change token changes. The token covers the TOML template's store path, the launcher's store path, and the public MCPorter configuration text. It also covers the configured keys and encrypted source paths for Moltis environment secrets. Changes anywhere in those encrypted source files trigger a restart, including credential rotations. The hook never reads or hashes decrypted values. Other assistant resource changes and unmanaged OAuth credentials do not independently trigger this hook. Home Manager still handles binary and LaunchAgent changes.

The first activation restarts Moltis because no token exists. The hook saves `~/.local/state/moltis/activation-token` (under `xdg.stateHome`) atomically with mode `0600` only after a successful restart. Failed rendering stops activation before the hook. Failed restarts leave the previous token intact for a retry. If the GUI login domain is absent, log in and repeat activation. The restart hook and synchronous refresh respect Home Manager's dry-run mode.

Use `moltis-log` to read `${XDG_STATE_HOME}/moltis/daemon.stdout.log` and `daemon.stderr.log`. With the default state directory, both files are under `~/.local/state/moltis/`. Linux retains `moltis.service` and its journal alias.

Fence command controls on Darwin are weaker than the Linux controls. The user accepts that difference. Native Darwin build and runtime validation remain pending. Build on Traya after approval, without an automatic SSH runtime test.

## Provider, presets, and Telegram channel

`default.nix` renders `~/.config/moltis/moltis.toml` through a sops template. Skrye and Zannah use the Gemini defaults below. Traya uses the Sol, Astra, and Luna routing described above:

- `coordinator` (`delegate_only = false`) uses `gemini::gemini-4-argon@reasoning-medium` (`reasoning_effort = "medium"`), and `review` uses `gemini::gemini-4-argon@reasoning-high` (`reasoning_effort = "high"`).
- `auxiliary` and `compression` presets use `gemini::gemini-3.8-flash`.
- `identity` sets `name` to `agentName` (`host.name`), and `user` sets `name = "Martin"`, `timezone = "Europe/London"`, and `write_mode = "off"`.
- `auxiliary` routes `compaction`, `title_generation`, and `vision` to `gemini::gemini-3.8-flash`, and `chat.compaction.mode` uses `"structured"`.
- `skills.enable_self_improvement` is `false`.
- `tools.agent_max_auto_continues` is `0`, which disables auto-continue `done` replies for all agents, so heartbeat runs that call several tools still return `HEARTBEAT_OK`. `tools.exec` sets `approval_mode = "never"` and `sandbox.mode = "off"` (Moltis runs inside `moltis-fenced`), and `tools.fs` sets `workspace_root` to `$HOME` with `track_reads = true` and `must_read_before_write = true`.
- `moltis-in-fence` exports per-agent GitHub and Git identity variables (`GH_TOKEN`, `GIT_AUTHOR_NAME`, `GIT_COMMITTER_NAME`, `GIT_AUTHOR_EMAIL`, and `GIT_COMMITTER_EMAIL`), disables commit and tag signing (`commit.gpgSign = false`, `tag.gpgSign = false`) via `GIT_CONFIG_*`, and rewrites GitHub SSH URLs (`git@github.com:` and `ssh://git@github.com/`) to `https://github.com/` authenticated through `gh auth git-credential`.
- `memory` uses `provider = "custom"` with `base_url = "http://127.0.0.1:8080/v1"` and `model = "qwen3-embedding-0.6b"`. Before `moltis` starts, `moltis-in-fence` deletes rows from `chunks`, `files`, and `embedding_cache` in `memory.db` when any chunk uses a different embedding model.
- `heartbeat` disables the internal 360-minute timer (`heartbeat.enabled = false`) when `agentic.moltis.githubCompanion.enable` is true, while preserving `every = "360m"`, `model`, `sandbox_enabled = false`, `deliver = true`, and `channel = "moltis"` (`to = "${TELEGRAM_ALLOWED_USERS}"`) for fallback runs if the companion is disabled. `moltis-github-companion` replaces the internal timer and drives targeted notification turns, 6-hour reconciliation sweeps, and weekly sweeps through `chat.send_sync` on `companion:github`. Those RPC turns do not trigger `heartbeat.deliver`. `moltis-github-companion` forwards non-`HEARTBEAT_OK` terminal assistant replies to Telegram (`sendMessage`), while Step 5 sends the voice briefing through `moltis-telegram-voice`.
- `voice.tts` selects the `openai` provider pointed at a local OpenAI-compatible shim (`base_url = "http://127.0.0.1:13139/v1"`) started inside `moltis-fenced`, with `model = "gemini-3.8-flash-tts"`. `traya` uses `voice = "en-gb-tutor-13"`. `skrye` uses `voice = "en-gb-commercial-6"` and `zannah` uses `voice = "en-gb-concierge-6"`. The shim reads `GEMINI_API_KEY` from the sops secret file, calls Google's `gemini-3.8-flash-tts` `generateContent` endpoint, and transcodes the returned WAV audio to Ogg Opus (`audio/ogg`) via `ffmpeg` so Moltis sends native Telegram voice notes without setting `voice.tts.openai.api_key`. On `POST /v1/audio/speech`, `moltis-tts-shim` rejects assessment badges and short `"ogg"` synthesis requests (`<= 16` stripped characters) with HTTP 400, and rejects `"ogg"` channel synthesis requests with HTTP 400 unless Martin's latest conversational message in Matrix `state.json` (or legacy `room-events.json`) explicitly requested audio or voice, while preserving `"opus"` synthesis for `moltis-telegram-voice`.
- `moltis-telegram-voice` (`<text>` or `--body-file <path>`) is installed in `home.packages` and `moltis-in-fence` `runtimeInputs`. It posts text to the local TTS shim (`http://127.0.0.1:13139/v1/audio/speech`) for Ogg Opus synthesis and uploads the voice note to Telegram `sendVoice` using `TELEGRAM_BOT_TOKEN` and `TELEGRAM_ALLOWED_USERS`.
- `voice.stt` selects the `whisper` provider pointed at the same local shim (`base_url = "http://127.0.0.1:13139/v1"`) with `model = "gemini-3.8-flash"`. On `POST /v1/audio/transcriptions`, the shim parses the `multipart/form-data` audio upload, normalizes or transcodes unsupported formats to `audio/ogg` via `ffmpeg`, calls `gemini-3.8-flash:generateContent` with `GEMINI_API_KEY`, and returns `{"text": "..."}` without setting `voice.stt.whisper.api_key`.
- `channels.telegram.moltis` defaults to `gemini-4-argon@reasoning-medium` on `gemini` (`gpt-6.1-sol@reasoning-medium` on `openai-codex` for `traya`) with `dm_policy = "allowlist"`, `group_policy = "disabled"`, `stream_mode = "edit_in_place"`, `stream_min_initial_chars = 30`, `edit_throttle_ms = 1000`, `reply_to_message = true`, and `otp_self_approval = false`.

The `[env]` table injects sops placeholders into the Moltis process environment at render time:

| Variable                 | Sops file             | Key                                |
| ------------------------ | --------------------- | ---------------------------------- |
| `GEMINI_API_KEY`         | `secrets/ai.yaml`     | `GEMINI_API_KEY`                   |
| `TELEGRAM_BOT_TOKEN`     | `secrets/moltis.yaml` | `TELEGRAM_BOT_<AGENT>`             |
| `TELEGRAM_ALLOWED_USERS` | `secrets/moltis.yaml` | `TELEGRAM_OPERATOR_IDS`            |
| `GH_TOKEN`               | `secrets/moltis.yaml` | `GITHUB_TOKEN_<AGENT>`             |
| `GIT_AUTHOR_EMAIL`       | `secrets/moltis.yaml` | `GITHUB_EMAIL_<AGENT>`             |
| `CONTEXT7_API_KEY`       | `secrets/mcp.yaml`    | `CONTEXT7_API_KEY`                 |
| `MATRIX_PASSWORD`        | `secrets/matrix.yaml` | `MATRIX_PASSWORD_<AGENT>`         |

## MCP through MCPorter

Skrye, Zannah, and Traya use MCPorter through `exec` for Model Context Protocol (MCP) access, in main and spawned agents. All three receive the five configured servers, including Linear. Other clients keep their native MCP configuration unchanged.

Nix generates a dedicated MCPorter configuration from the Moltis-filtered shared registry, with `imports = []`. Its path is `moltis/mcporter.json` relative to `config.xdg.configHome`. The runtime supplies its absolute path through `MCPORTER_CONFIG` and explicitly selects the pinned MCPorter binary. No editor configuration imports or automatic OAuth login are part of this route. Credentials reach MCPorter through SOPS-managed environment variables and runtime wrappers, never command arguments.

Linear uses a separate application for each agent: Zannah, Skrye, and Traya. SOPS reads `moltis/<agent>/client_id` and `moltis/<agent>/client_secret` from `secrets/linear.yaml` into Moltis-only files with mode `0400`. These credentials do not enter the TOML environment or the Nix store. Interactive clients retain their existing personal or work credentials.

The Moltis-only `mcporter` wrapper removes inherited `LINEAR_API_KEY` and starts MCPorter without requesting a Linear token. Only the Linear server entry starts the dedicated `moltis-linear-server` child. This child reads the credential files and resolves a cached or new `client_credentials` token from `https://api.linear.app/oauth/token`. It then runs `mcp-proxy --transport streamablehttp` with the configured Linear URL and supplies the token through `API_ACCESS_TOKEN`. The proxy sends the token as a Bearer header. Neither MCPorter nor unrelated servers receive this app token, and unrelated servers remain available during a Linear issuer failure.

The fixed scope is `read,write`, without `admin`. Project and document changes, plus comment edits in the projected tracker workflows, need `write` rather than the narrower creation scopes.

The Linear child caches the token under `${XDG_STATE_HOME}/moltis/linear-<agent>/token.json`, using a private directory, mode `0600`, a lock, and atomic replacement. Each new Linear connection checks the cache and renews the token when it is within one day of expiry. Renewal is lazy, including during unattended gateway operation, rather than scheduled or required for every MCPorter invocation. Linear uses an ephemeral connection, so a shared daemon cannot retain an older token. Credential or scope changes invalidate the cache identity.

Credential resolution has a 30-second deadline, with a 20-second HTTP timeout and no redirect support. If renewal fails, the Linear child uses the previous app token only while more than one hour remains. Otherwise, the Linear child stops before the proxy starts, without a personal-token fallback. The wrapper never retries an MCP operation. If Linear revokes a token early without a local credential change, remove only that agent's `token.json` before the next authorised call. Verify remote state before you retry a failed write.

Moltis no longer registers these servers directly with the model. This avoids exposing Linear's URI tool schemas to Traya's Codex provider. Main and spawned agents use the same CLI recipe in [TOOLS.md](TOOLS.md). The CLI adds process and connection work. Latency is unmeasured, and no token savings or performance measurements are established.

An empty TOML server table is insufficient for migration: persisted `mcp-servers.json` entries override the empty table. Before gateway startup, the migration helper disables persisted native entries but preserves their definitions and unknown fields. It creates `mcp-servers.json.pre-mcporter.bak` beside the registry without overwriting an existing backup. Both files use mode `0600`, and registry replacement is atomic. The helper rejects invalid data, symlinks, unsafe ownership, and a data directory that other users can write. These repository changes prepare all three agents together.

The main agent's `tools.policy.deny = [ "mcp_*" ]` filters native MCP tools. Generated Markdown presets deny the five exact native management tools: `mcp_list`, `mcp_add`, `mcp_remove`, `mcp_status`, and `mcp_restart`. TOML presets, including the retained upstream `research` and `coder` presets, also receive these denies and CLI instructions. This is not a global MCP shutdown or a hard security boundary. Spawned agents do not inherit that global policy. Their preset denies and explicit parent briefings must retain the CLI route and native management restrictions. An explicit non-empty `deny_tools` list replaces preset defaults, so callers must preserve the complete preset denylist rather than supply a partial override.

Keep configuration and instructions in their Nix-managed sources, not installed files. Use [TOOLS.md](TOOLS.md) for focused discovery, JSON calls, output bounds, and spawn briefings. If a write times out, its outcome is unknown. Verify remote state through an authorised read before any retry, and never replay a write automatically.

## Shared Matrix room

Normal deployment enables Matrix on `skrye`, `zannah`, and `traya`. Malak automatically provisions the accounts and `the-cauldron`. All three agents use the fixed room ID `!the-cauldron:matrix.wimpys.world`, so deployment needs no room-ID handoff. Setting `agentic.moltis.matrix.enable = false` removes the channel, its runtime secret, the companion, and the council hook. Keep Telegram direct messages for operator work and voice.

Each agent reads its password from `secrets/matrix.yaml`: `MATRIX_PASSWORD_SKRYE`, `MATRIX_PASSWORD_ZANNAH`, or `MATRIX_PASSWORD_TRAYA`. SOPS renders the agent's `MATRIX_PASSWORD` placeholder at runtime. Never put plaintext passwords in Nix values, command arguments, or logs.

The channel (`channels.matrix.matrix-<agent>`) uses `https://matrix.wimpys.world`, `auth_mode = "password"`, `ownership_mode = "user_managed"`, and `private_instance = true`. Stable gateway device IDs are `MOLTIS_SKRYE`, `MOLTIS_ZANNAH`, and `MOLTIS_TRAYA`. The default `userId` follows the agent identity, including `@traya:matrix.wimpys.world` on Traya.

The room allowlist and automatic joining permit only `roomId`. The user allowlist permits `@martin:matrix.wimpys.world`, `@skrye:matrix.wimpys.world`, `@zannah:matrix.wimpys.world`, and `@traya:matrix.wimpys.world`. Operators contain only `@martin:matrix.wimpys.world`. Streaming is off, and one-time-password self-approval is disabled. See the [pinned Matrix documentation](https://github.com/moltis-org/moltis/blob/20261023.01/docs/src/matrix.md).

Room replies require explicit full Matrix ID mentions (`@traya:matrix.wimpys.world`, `@skrye:matrix.wimpys.world`, or `@zannah:matrix.wimpys.world`). Mention checks also accept `@room` and mentions from other bots, so mention gating alone does not prevent response loops. The council hook injects anti-sycophancy rules, single-peer tagging limits, and a 9-turn bot budget per message from `@martin:matrix.wimpys.world`.

When `agentic.moltis.matrix.enable` is true, `moltis-in-fence` starts `moltis-matrix-companion` beside the gateway. Each companion signs in with device ID `MOLTIS_COMPANION_<AGENT>` (`MOLTIS_COMPANION_SKRYE`, `MOLTIS_COMPANION_ZANNAH`, and `MOLTIS_COMPANION_TRAYA`) and stores durable state with mode `0600` under `~/.local/state/moltis/matrix-companion-<agent>/` (`${XDG_STATE_HOME}/moltis/matrix-companion-<agent>/`): operational `state.json` (`0600`, plus `companion.lock`), credential `auth.json` (`0600`), and `active-turn.json` (`0600`, plus `active-turn.lock`). On startup, `CompanionStateStore` migrates any legacy `sync-state.json`, `outbox.json`, `companion-state.json`, and `room-events.json` into `state.json` under `companion.lock` and unlinks those four legacy files, while migrating any embedded `state["auth"]` out of `state.json` into `auth.json` (`0600`) so `state.json` never stores `access_token` credentials. Pass `moltis-matrix-companion --status` to print a bounded, credential-free JSON status summary (`agent_name`, `room_id`, `state_dir`, `state_file`, `auth_file`, `authenticated`, `user_id`, `device_id`, `next_batch`, `active_session_key`, `cutoff_ms`, `is_provisional`, `active_turn`, and `counts`) and exit `0` without starting `/sync` or logging in. Progress and status `m.notice` events (and `m.replace` edits) are excluded from the 100-message `recent_events` room buffer so they do not evict conversational context.

A bounded single-worker queue (depth 32) assesses unmentioned conversational room messages (`m.text` and caption-bearing bot `m.audio` events) from allowlisted peers after the active `/new` cutoff. In `companion.py` and `moltis-tts-shim`, `/new` detection strips allowlisted Matrix user IDs and agent display-name pill mentions (`@Skrye`, `Skrye`, `@Traya`, `Traya`, `@Zannah`, `Zannah`, `@Martin`, `Martin`), and `SessionGenerationResolver` plus `resolve_hook_session_generation` anchor `cutoff_ms` to the targeted `/new` event's Matrix `origin_server_ts` (`last_new_origin_server_ts_ms`) so host clock skew or delayed session-start replies never drop post-`/new` room messages. The assessment prompt sanitises voice-trigger words so assessment runs never trigger `ReplyMedium::Voice`. The worker calls local JSON-RPC `chat.send_sync` (`https://127.0.0.1:13131/api/rpc`, `ASSESSMENT_TIMEOUT_SECS = 45.0`) on the agent's `mainModel` (`gemini::gemini-4-argon@reasoning-medium` on `skrye` and `zannah`, `openai-codex::gpt-6.1-sol@reasoning-medium` on `traya`) in ephemeral session `companion:matrix-assess` with `active_tools = []` and `_tool_policy = {"deny": ["*"]}`. When `/new` advances the agent's Matrix session generation (`active_session_key` or `cutoff_ms`), the companion resets `companion:matrix-assess` `history.jsonl` (`last_assess_reset_session_key` and `last_assess_reset_cutoff_ms` in `state.json`). It rechecks the active session generation and cutoff before the RPC call and again before posting `m.reaction`. Each assessment posts one badge:

- `👌🏻` - acknowledged, no contribution requested (does not indicate agreement).
- `👍🏻` - agreement, no contribution requested.
- `✋🏻` - a response, question, objection, or moderator action is needed.

Turn status uses an Option 1A writer split across `active-turn.json` and `state.json`. The `matrix-council-context` hook (`moltis-matrix-council-hook`) imports shared helpers from `matrix-companion/companion.py`, reads unified `state.json`, and is the sole writer of `active-turn.json` (under `active-turn.lock`) on `BeforeLLMCall` and `BeforeToolCall`. The companion is the sole writer of `state.json` (under `companion.lock`). It binds a turn to the room event that holds the agent's `👀` acknowledgement reaction and a unique unbound `(sender, body)` match, posts a static `🐝` reaction while the turn is active, and removes `🐝` when the turn ends.

While `chat.peek` reports `active = true`, the companion posts an `m.notice` progress message after 5 seconds. It edits that notice in place (`m.replace`) every 3 seconds with wall-clock `MM:SS` elapsed time (`HH:MM:SS` at 1 hour and above) and step count (`<emoji> MM:SS elapsed - Step X`), without `@...:matrix.wimpys.world` mentions:

- `💭` - model activity (`BeforeLLMCall` on iteration 1, or after a 3-second dwell on later iterations).
- `🔎` - reading or searching (`Read`, `Grep`, `Glob`, `web_fetch`, `read_skill`, `memory_search`, `memory_get`, `sessions_history`, `sessions_search`, `sessions_list`, `codebase_peek`, `codebase_search`, `codebase_status`).
- `✍️` - writing or editing (`Write`, `Edit`, `MultiEdit`, `create_skill`, `update_skill`, `patch_skill`, `delete_skill`, `memory_save`, `memory_delete`, `memory_forget`, `checkpoint_restore`).
- `🐚` - shell commands (`exec` or `process`).
- `🔧` - other tool calls.

When a turn that posted a progress notice finishes, the companion reconciles completion within a 30-second window (`COMPLETION_RECONCILE_WINDOW_MS = 30000`) and edits the notice in place instead of redacting it. When back-to-back turns keep `chat.peek` active across a `run_id` transition, `TurnStatusReconciler` verifies the superseded run's committed assistant reply and outbound Matrix room message before cleaning up run artefacts. Confirmed completion becomes `🏁 <Agent> finished in MM:SS` (measured to the first observed inactive state or superseding run boundary). Unverified or aborted turns become `⚠️ <Agent> ended after MM:SS · Completion unverified`. Short turns under 5 seconds do not create a progress or terminal notice.

All three agents plan, research, design, implement, test, review, and challenge proposals. Skrye also acts as first responder, chat moderator, and invitation router. Direct requests go to the named agent. Martin retains final decisions and work authorisation.

Skrye's companion selects speakers for untagged room messages with a 25-second deadline (`WAKEUP_DEADLINE_MS = 25000`). Traya's companion only relays invitations to Skrye, not moderation decisions. Moltis ignores self-sent messages, so invitations to Skrye need a different sender.

- Direct floor invitations and stateless relay: when one or more expected assessors react with `✋🏻` and all expected assessors have reacted (or when the 25-second deadline expires), `skrye`'s companion selects other raised hands before Skrye, both initially and from `pending_hands`. Among those peers, it selects the least-recent speaker in `recent_events`, with ties broken by `sha256(f"{target_event_id}:{user_id}")`. When the selected speaker is `@traya:matrix.wimpys.world` or `@zannah:matrix.wimpys.world`, `skrye` posts `🛎️ Inviting <target-id> to the floor on <Sender>'s message: "<preview>" ✋🏻` directly. When the selected speaker is `@skrye:matrix.wimpys.world`, `skrye` posts a non-mentioning `m.notice` with `"org.wimpysworld.companion_relay"` metadata, and `traya`'s companion statelessly relays the floor invitation for `@skrye:matrix.wimpys.world` (using deterministic scope `relay-wakeup:<selection_id>` when within the 9-turn bot budget and with no newer conversational message or `/new` reset).
- Companion-managed `pending_hands` queue: when multiple agents raise `✋🏻`, remaining raised hands stay queued in `pending_hands` for that `martin_root_id`. If an active speaker mentions another peer, `pending_hands` is retained while `active_speaker` advances to the tagged peer; once the active turn chain settles without a further peer tag, `skrye`'s companion invites the next remaining raised-hand agent. `pending_hands` removes an agent only when that agent posts a conversational turn on the current root message or withdraws `✋🏻`, and clears when `@martin:matrix.wimpys.world` posts a new message, when `/new` runs, or when turn caps are reached.
- Silent closure: when all expected assessors return `👌🏻` or `👍🏻` with zero `✋🏻`, the target closes silently without waiting 25 seconds. A late `✋🏻` reopens the target.
- Moderator fallback: when Martin's untagged message has no raised hands and Skrye has not reacted after 25 seconds, the companion requests Skrye through Traya's stateless relay.
- Suppression and caps: any newer allowlisted conversational message from Martin suppresses pending wake-ups for older targets. Wake-ups cap at 3 per `@martin:matrix.wimpys.world` root message and 9 bot turns since `@martin:matrix.wimpys.world`'s last message.
- `/new` cancellation: an untagged `/new` or a `/new` that mentions Skrye or Traya, `@skrye`'s own session change, or target redaction cancels pending wake-ups at or before the reset timestamp.

The `matrix-council-context` hook runs on `BeforeLLMCall` and `BeforeToolCall` with a 10-second timeout, delegating session generation resolution, `history.jsonl` loading, tool-phase classification, `active-turn.json` updates, persona restoration, assessment prompt stripping, and `<room_context>` formatting to shared helpers imported from `companion.py`. For `companion:matrix-assess*` sessions on `BeforeLLMCall`, it restores private workspace persona files with `tool_count = 0` (`SOUL.md`, `USER.md`, `AGENTS.md`, `GUIDELINES.md`, without `TOOLS.md`) and strips `<available_skills>...</available_skills>` XML blocks and `TOOLS.md` / `## Available Tools` sections while preserving `IDENTITY.md`, `SOUL.md`, and memory prefetch chunks. For interactive room sessions, it skips inactive sessions; on `BeforeToolCall`, it updates `active-turn.json` and exits; on `BeforeLLMCall`, it also restores private workspace persona files (`SOUL.md`, `USER.md`, `AGENTS.md`, `GUIDELINES.md`, and `TOOLS.md` when `tool_count > 0`) if absent from the system prompt, and appends the council protocol plus a `<room_context>` block read from unified `state.json`. Both `AGENTS.md` and the council protocol instruct agents to keep Matrix group chats text-only unless Martin explicitly asks for a voice note, and to use display names (`Skrye`, `Traya`, `Zannah`) in prose and code spans unless waking a peer. The `<room_context>` block is bounded by the active session's `/new` cutoff (anchored to the targeted `/new` event's Matrix `origin_server_ts` when present, or resolved from `moltis.db` `channel_sessions` and `sessions.created_at`, or the companion's `provisional_cutoff_ms` in `state.json`) and includes up to 12 unmentioned allowlisted conversational messages (6,000 characters) and reactions on the latest 10 post-cutoff events.

FluffyChat is included for Linux desktop chat. The user configures the phone client separately. Both clients use the public homeserver URL above. See the [server deployment documentation](../../../../nixos/_mixins/server/private-matrix/README.md) for automatic provisioning and the accepted consequences of database loss. Live client checks require deployment.

## GitHub companion

When `agentic.moltis.githubCompanion.enable` is true (default on `skrye`, `zannah`, and `traya`), `moltis-in-fence` starts `moltis-github-companion` beside the gateway. Each companion stores durable state with mode `0600` in directory mode `0700` under `$XDG_STATE_HOME/moltis/github-companion-<agent>/` (`~/.local/state/moltis/github-companion-<agent>/`): `state.json`, `active-dispatch.json`, `security-events.jsonl`, `coordinator.lock`, `companion.lock`, `auth.json`, and `outbox.json`.

### Poll timing and crash recovery

On startup, the companion migrates any legacy state into `state.json` or falls back to clean defaults, reads `next_poll_at_ms` from `state.json`, and sleeps until that timestamp when it is in the future, or aligns to the next dedicated 30-minute wall-clock slot when `next_poll_at_ms` is `None` or in the past.

Each agent polls on dedicated 30-minute (`1800s`) wall-clock slots with a 10-minute stagger between agents:

- `skrye`: `:00` and `:30` past the hour.
- `traya`: `:10` and `:40` past the hour.
- `zannah`: `:20` and `:50` past the hour.

Before each HTTP poll, the companion writes the provisional `next_poll_at_ms` for the next 30-minute slot to `state.json`. If this write fails, the companion aborts the poll before sending a request. After the response arrives, the companion computes the longest wait from the next 30-minute slot, `X-Poll-Interval`, `Retry-After`, or `max(0, X-RateLimit-Reset - now_sec)`, and updates `state.json` atomically.

### 30-minute notification and open pull-request polling

Every 30-minute (`1800s`) poll cycle queries `/notifications` (`gh-api-safe notifications --paginate -i` with `If-Modified-Since` when `last_modified` exists in `state.json`) and one GraphQL open pull-request search across six owners: `wimpysworld`, `linuxmatters`, `quickemu-project`, `noughtylinux`, `oval-tutu`, and `flexiondotorg`. On `HTTP 304 Not Modified`, notification state does not advance.

The companion stores `{handled_updated_at, handled_head_sha, handled_ci_state, retry_count}` per notification thread and pull request key in `state.json` before advancing `last_modified`. When a notification is a `CheckSuite` or `WorkflowRun` with `subject.url == null`, the companion marks it handled in `state.json` and calls `gh-notification-dismiss` automatically.

The open pull-request poll inspects `number`, `author`, `headRefOid`, `reviewDecision`, `statusCheckRollup`, `updatedAt`, and `reviewRequests` on each non-draft open pull request. It triggers a targeted turn on the agent's 30-minute slot when a trusted author opens an unrequested pull request (`unrequested_pr`) or requests review (`review_requested`), pushes a new `headRefOid` (`head_push`), or has `statusCheckRollup` turn green (`SUCCESS`) after `APPROVED` (`ci_green_after_approval`). `traya` is reserved for human and peer code review and explicit `@traya` or `@sith-traya` mentions, and does not run automated update turns or sweeps. Automated update pull requests (`dependabot[bot]`, `app/dependabot`, `github-actions[bot]`, `app/github-actions`, and `wimpysworld/nix-config` Freshener) are partitioned across `("skrye", "zannah")` with `sha256("v1:<owner>/<repo>:pr:<number>") mod 2` (`0` -> `skrye`, `1` -> `zannah`), so only the assigned owner wakes for routine bot pull requests. Initial pull-request reviews dispatch immediately. After a completed pull-request review turn, the companion sets a 15-minute per-pull-request follow-up cooldown (`PR_REVIEW_COOLDOWN_MS = 15 * 60 * 1000`, `followup_cooldown_until_ms` in `state.json`). Follow-up notification and `head_push` turns queue (`pending_followup = true`) until the cooldown expires, while `ci_green_after_approval` bypasses the cooldown so approved pull requests with green CI and zero unresolved review threads merge immediately. Self-authored comments, reviews, and pushes update `state.json` without waking the agent. When a thread or pull request receives newer activity during an active turn (`in_flight == true`), the companion sets `pending_followup = true` in `state.json` so a follow-up turn runs before `gh-notification-dismiss` marks the thread done. Pass `--read-only-trial` to test poll timing, pagination, conditional headers, and `state.json` updates without dispatching turns or dismissing notifications.

### Inline trigger evaluation and coercion alerts

Before dispatching a targeted notification turn, `TrustFilterAndSnapshotBuilder` fetches only the triggering comment or review (`latest_comment_url`) and subject metadata needed to verify actor trust and trigger reason. It strips HTML comment blocks (`<!-- ... -->`) and checks the actor against the trusted actor allowlists: `TRUSTED_INSTRUCTION_ACTORS` (`flexiondotorg`, `sith-skrye`, `sith-traya`, and `sith-zannah`) and `TRUSTED_BOT_ACTORS` (`dependabot[bot]`, `app/dependabot`, `github-actions[bot]`, `app/github-actions`, and `cubic-dev-ai[bot]`). Only `TRUSTED_INSTRUCTION_ACTORS` can issue instructions on issues or pull requests.

The evaluator filters out self-authored activity, unmentioned peer `APPROVED` reviews (`sith-*` approvals that do not mention the current agent), and unmentioned peer or bot comments and reviews (`sith-*` and `cubic-dev-ai[bot]`) on a pull request `head_sha` that the current agent already reviewed (`handled_head_sha == head_sha`), updating `state.json` without starting a model turn. When a `PullRequest` notification targets a closed, merged, or draft pull request, the companion skips dispatch and calls `gh-notification-dismiss` directly. When a notification passes evaluation, the companion passes `repo`, `number`, `kind`, `head_sha`, `trigger_reason`, and the trusted comment or review identifier (`comment_id`, `review_id`, `trusted_item_id`) inline in the dispatch prompt.

When an untrusted actor interacts with a thread or an actor attempts coercion or `@sith-*` command injection (such as prompt overrides, `ignore previous instructions`, HTML comment blocks, tool invocation directives, merge or dismiss commands, or role spoofing), the companion logs one deduplicated record per `(repo, number, item_kind, item_id)` in `security-events.jsonl` (mode `0600`). On coercion or `@sith-*` command injection, only `skrye` (`self.agent_name == "skrye"`) sends one sanitised Matrix `m.notice` to `!the-cauldron:matrix.wimpys.world` (device ID `MOLTIS_GH_COMPANION_<AGENT>`, with zero untrusted excerpts and zero `@...:matrix.wimpys.world` mentions) and one Telegram alert (`sendMessage`).

### Decoupled polling and single-flight execution coordinator

The 30-minute (`1800s`) poll tick updates `state.json` under `companion.lock` and is decoupled from `LocalExecutionCoordinator.execute_dispatch`, which serialises targeted turns, 6-hour reconciliation sweeps, and weekly sweeps under `coordinator.lock`. Sweep schedules are partitioned as follows:

- 6-hour reconciliation sweeps (`reconcile_sweep`) run on `skrye` and `zannah` only, staggered by 3 hours (`skrye` at `0h`, `zannah` offset by `3h`).
- Weekly organisation sweeps (`weekly_sweep`) run on Tuesday (`skrye`) and Thursday (`zannah`) after `09:00 Europe/London`.
- `traya` is reserved for human and peer code review and explicit mentions, and does not run automated update turns or sweeps.

If `coordinator.lock` is busy during a poll cycle, the companion records new notifications and pull-request state in `state.json` (`pending_followup = true` when already `in_flight`) and returns without blocking the poll loop.

Before calling `chat.send_sync` (`https://127.0.0.1:13131/api/rpc`, session `companion:github`), the coordinator generates a `dispatch_id`, writes `active-dispatch.json` (`0600`), and sends a one-line Telegram start-of-work notice via `TelegramClient.send_message` to the first allowed chat ID from `TELEGRAM_ALLOWED_USERS`. Targeted human and peer pull-request reviews and issue mentions dispatch on `reviewModel` (`gemini::gemini-4-argon@reasoning-high` on `skrye` and `zannah`, `openai-codex::gpt-6-astra@reasoning-medium` on `traya`), while automated update pull requests (`dependabot[bot]`, `github-actions[bot]`, and `wimpysworld/nix-config` Freshener), 6-hour reconciliation sweeps, and weekly sweeps dispatch on `mainModel` (`gemini::gemini-4-argon@reasoning-medium` on `skrye` and `zannah`, `openai-codex::gpt-6.1-sol@reasoning-medium` on `traya`).

The coordinator holds `coordinator.lock` until `chat.peek` reports `active == false` and `~/.moltis/sessions/v1/<encoded_key>/history.jsonl` contains the user record for `dispatch_id` followed by a terminal assistant record. When a turn succeeds and produces a non-`HEARTBEAT_OK` terminal assistant reply, the companion forwards that text to Telegram (`sendMessage`), while `moltis-telegram-voice` sends the voice briefing. Successful reconciliation sweeps advance `last_reconcile_sweep_at_ms` and clear reconciliation retry state. Successful weekly sweeps advance `last_weekly_sweep_date` and `last_reconcile_sweep_at_ms` and clear both weekly and reconciliation retry state. When a turn reports a tool or task failure, or when `chat.peek` reports `active == false` without a terminal assistant record (interrupted-turn recovery on startup or after an RPC error), the coordinator marks the turn failed, clears `active-dispatch.json`, and suppresses routine Telegram delivery. Targeted thread failures increment per-thread `retry_count` in `state.json` up to `MAX_THREAD_FAILURE_RETRIES` (`3`). Failed or interrupted reconciliation and weekly sweeps record sweep attempt timestamps (`last_reconcile_sweep_attempt_at_ms` or `last_weekly_sweep_attempt_at_ms`), increment failure counts (`reconcile_sweep_failure_count` or `weekly_sweep_failure_count`), and persist bounded exponential-backoff retry deadlines (`reconcile_sweep_retry_after_ms` or `weekly_sweep_retry_after_ms`, from `15` minutes up to `120` minutes) in `state.json` without advancing `last_reconcile_sweep_at_ms` or `last_weekly_sweep_date`.

### `HEARTBEAT.md` dependency updates and security alert sweeps

`HEARTBEAT.md` Steps 3A (6-hour reconciliation sweep) and 4 (weekly organisation sweep) run on `skrye` and `zannah` only. Automated update pull requests (`dependabot[bot]`, `app/dependabot`, `github-actions[bot]`, `app/github-actions`, and `wimpysworld/nix-config` Freshener) are partitioned across `("skrye", "zannah")` with `sha256("v1:<owner>/<repo>:pr:<number>") mod 2` (`0` -> `skrye`, `1` -> `zannah`). The assigned owner reviews, repairs, approves, and merges its owned automated dependency updates (patch, minor, major, grouped, and GitHub Actions) autonomously across all configured owners without a major-upgrade approval request to `flexiondotorg`. `traya` is reserved for human and peer code review and explicit mentions, and never runs automated update turns or sweeps. When `skrye` or `zannah` opens a superseding dependency or workflow pull request, it requests review only from the other Gemini peer (`sith-zannah` for `skrye`, `sith-skrye` for `zannah`). Before `skrye` or `zannah` approves or merges a dependency update (except under `flexiondotorg`), it verifies against open Dependabot alerts that the target version does not leave an open advisory for that package unresolved when a patched version exists. Repositories with no configured Continuous Integration (CI) checks (`statusCheckRollup` is empty or `NONE`) and pull requests whose only red CI checks fail for reasons unrelated to the dependency change (such as broken baseline workflows, absent pull-request publishing secrets, or runner billing blocks) still merge with `gh-bot-merge <pr-url>` once approved with zero unresolved review threads. Agents leave an automated dependency update unmerged only when concrete evidence shows that the dependency change itself breaks the build and cannot be automatically repaired, or when the update introduces or leaves an unresolved vulnerability.

`HEARTBEAT.md` Steps 3B (6-hour reconciliation sweep) and 4 (weekly organisation sweep) poll open Dependabot and CodeQL alerts directly through `gh-api-safe --paginate` across five organisations: `wimpysworld`, `linuxmatters`, `quickemu-project`, `noughtylinux`, and `oval-tutu`. Agents never poll `flexiondotorg` for Dependabot or CodeQL alerts.

Alerts group by `<owner>/<repo>:dependabot:<ecosystem>:<package>` or `<owner>/<repo>:code-scanning:<tool>:<rule_id>:<file_path>`. `skrye` and `zannah` compute ownership with `sha256("v1:<group_key>") mod 2` mapped to `("skrye", "zannah")` (`0` -> `skrye`, `1` -> `zannah`), derive the deterministic `security/*` fix branch, and check remote heads (`git ls-remote --heads`) and pull requests (`gh pr list --state all --head <branch>`) directly:

- When an open `security/*` branch or open pull request already exists, the agent skips the group.
- When a matching `security/*` pull request was closed without merging, the agent skips the group and never recreates or force-pushes the rejected branch without an explicit instruction from `flexiondotorg`.

### Commit-pinned merge verification in `gh-bot-merge`

`gh-bot-merge` reads `headRefOid` on every pull request and requires commit-pinned approvals (`commit.oid == headRefOid`) in `latestOpinionatedReviews`. Stale peer approvals fail verification with exit code `64`. Every `gh pr merge` call passes `--match-head-commit <headRefOid>` so that GitHub rejects the merge if the branch head changes after verification.

## Projection surfaces

| Destination                          | Source                                                                  | Notes                                                                                                                           |
| ------------------------------------ | ----------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `~/.moltis/agents/<name>.md`         | `agents/<name>/prompt.md` + `compose.readHeader`                        | One file per coding agent, file by file. Moltis writes runtime workspaces into `~/.moltis/agents/`.                             |
| `~/.moltis/skills/<name>/SKILL.md`   | `compose.composeSkillsFor "moltis"`, allowlisted commands               | Skill directories with `SKILL.md`; Moltis discovers skills one level deep and never writes inside a personal skill.             |
| `~/.moltis/IDENTITY.md`              | `moltis/IDENTITY_<AGENT>.md`                                            | YAML frontmatter (`name`, `emoji`, `theme`), deployed via `ownedFiles` (`kind = "file"`, mode `0600`).                          |
| `~/.moltis/agents/main/IDENTITY.md`  | `moltis/IDENTITY_<AGENT>.md`                                            | Same identity deployed into the `main` agent workspace via `ownedFiles` so Moltis's first-run seed copy never goes stale.       |
| `~/.moltis/AGENTS.md`                | `moltis/AGENTS.md` + `compose.houseStyleBody`                           | Plain Markdown, no frontmatter. Defines reciprocal PR and review workflows (`ownedFiles`, mode `0600`).                         |
| `~/.moltis/agents/main/AGENTS.md`    | `moltis/AGENTS.md` + `compose.houseStyleBody`                           | Same instructions deployed into the `main` agent workspace via `ownedFiles` so Moltis's first-run seed copy never goes stale.   |
| `~/.moltis/TOOLS.md`                 | `moltis/TOOLS.md` with Nix-derived `@ENVIRONMENT@`                     | Plain Markdown, deployed via `ownedFiles` as a regular file, mode `0600`. |
| `~/.moltis/agents/main/TOOLS.md`     | Same composed `moltis/TOOLS.md`                                       | Identical content in the `main` agent workspace, with the same ownership and mode. |
| `~/.moltis/docs/moltis/GUIDELINES.md` | `moltis/GUIDELINES.md` | Fallback for private chat, deployed through `ownedFiles` as a regular file, mode `0600`. |
| `~/.moltis/agents/main/GUIDELINES.md` | Same `moltis/GUIDELINES.md` | Main profile override, with identical content, ownership, and mode. |
| `~/.moltis/SOUL.md`                  | `assistant-moltis-soul` sops template (`SOUL_<AGENT>` + `SOUL_ALL`)     | Agent soul from `secrets/moltis.yaml` followed by `SOUL_ALL`, deployed via `ownedFiles` (`kind = "file"`, mode `0600`).         |
| `~/.moltis/agents/main/SOUL.md`      | `assistant-moltis-soul` sops template (`SOUL_<AGENT>` + `SOUL_ALL`)     | Same soul deployed into the `main` agent workspace via `ownedFiles` so Moltis's first-run seed copy never goes stale.           |
| `~/.moltis/USER.md`                  | `assistant-moltis-user` sops template (`USER` in `secrets/moltis.yaml`) | User profile deployed via `ownedFiles` (`kind = "file"`, mode `0600`).                                                          |
| `~/.moltis/agents/main/USER.md`      | `assistant-moltis-user` sops template (`USER` in `secrets/moltis.yaml`) | Same user profile deployed into the `main` agent workspace via `ownedFiles`.                                                    |
| `~/.moltis/HEARTBEAT.md`             | `moltis/HEARTBEAT.md` (per-host schedule substituted)                   | Inline trigger metadata turns, 3-hour staggered 6-hour reconciliation sweeps (`skrye` and `zannah` only), weekly sweeps (`skrye` Tuesday, `zannah` Thursday), `mod 2` bot PR and security alert ownership across `("skrye", "zannah")`, and `traya` reserved for Mode 1 code review and explicit mentions. |
| `~/.moltis/agents/main/HEARTBEAT.md` | `moltis/HEARTBEAT.md` (per-host schedule substituted)                   | Same heartbeat specification deployed into the `main` agent workspace via `ownedFiles` (`kind = "file"`, mode `0600`).          |

Generated agent frontmatter contains `name`, `theme`, and `deny_tools`. Moltis has no `description` field, so `theme` carries the agent description (Moltis `AgentFrontmatter`, `crates/config/src/agent_defs.rs`). The body becomes the preset's `system_prompt_suffix`.

Moltis's `read_skill` tool (`crates/tools/src/skill_tools/read_ops.rs`) rejects symlinked skill directories and rejects sidecar files whose canonical path resolves outside the skill directory. Therefore, all skills under `~/.moltis/skills/<name>/` (project `SKILL.md` files, recursive sidecar files, command-derived skills, sops-rendered secret skills, and optional Chainguard skills) deploy through `ownedFiles` as real directories and regular files (`kind = "file"`, mode `0600`).

## Tool instructions and ownership

Edit the repository's [TOOLS.md](TOOLS.md), not either installed copy. Nix replaces its single `@ENVIRONMENT@` marker with public host and provider facts. The generated section uses the configured home directory for Linux or Darwin paths and describes the existing Fence restrictions. It grants no broader access. Gemini's parser restriction applies only to Gemini, not Traya's Codex chat provider. All three agents access Linear through MCPorter, as described above.

Only the Tools section moves out of Moltis's `AGENTS.md`. Role, workflow, Safety, and house-style instructions remain in `AGENTS.md` and its composition.

For normal chat, Moltis reads profile `TOOLS.md` first and falls back to the root copy. It injects exactly one copy on each request. A deployed tool-instruction change needs no daemon restart for this path. Other request paths remain unverified. Nix activation owns both generated files. Upstream Moltis seeds a missing root `TOOLS.md` from its default comment-only content and copies the root file into a missing main workspace copy. Startup does not overwrite existing files.

Migration accepts the known previous `AGENTS.md` hash and the upstream comment-only `TOOLS.md` seed. Unknown custom content, including an unowned empty file, remains untouched and causes a deployment conflict. Web UI edits do not bypass ownership checks and can cause the same conflict. Keep the repository source canonical and review conflicts before activation.

## Guidelines override

Edit [GUIDELINES.md](GUIDELINES.md) to change the Guidelines section for normal private chat. This non-empty file replaces the whole compiled section, not only its MCP advice. It retains applicable upstream tool, safety, result-checking, and silent-reply guidance while selecting MCPorter instead of native MCP tools.

The loader checks `~/.moltis/agents/<agent_id>/GUIDELINES.md` first, then `~/.moltis/docs/moltis/GUIDELINES.md`. It does not read `~/.moltis/GUIDELINES.md`. Nix delivers identical regular files to the fallback path and `agents/main`, with mode `0600`. Other profiles can supply their own override before the fallback.

Normal private chat reloads these instructions for each request, without a daemon restart. Non-private chat paths retain compiled defaults. Spawned workers do not use this compiled Guidelines section. Their existing preset suffixes and parent briefings supply MCPorter instructions and the `TOOLS.md` recipe. This override is not global.

The pinned upstream workspace seeding code creates no `GUIDELINES.md` default, so this change adds no adoption hashes. Unknown unowned files, empty files, modified owned files, and symlinks remain protected by ownership checks. Conflicts stop deployment rather than overwrite those files. Review each conflict before activation.

`TOOLS.md` also requires agents to treat returned error content as failure, even when MCPorter exits with status zero.

## Command allowlist

Moltis has no slash-command surface. Its importer models a command as a skill (`create_skill_from_command`, `crates/import-core/src/skills.rs`), so selected commands deploy as skills under `~/.moltis/skills/`. An entry qualifies only when its `command.toml` proves `caller-context = true` and its body assumes no native platform tooling. The allowlist (`moltisCommandAllowlist` in `../assistants/default.nix`):

- `ack` - acknowledge feedback, conversational
- `ahem` - correct the last response, conversational
- `ask` - answer a question in the caller's context
- `call` - name a called agent, context-only
- `clarify-plan` - question a plan draft, conversational
- `gist` - rewrite the previous response concisely
- `handover-fresh` - handover to a fresh session, context-only
- `oi` - draw attention to the current work, conversational
- `ready` - session priming prompt, context-only

Each command runs in the caller's context, so no dispatch wrapper is needed, and Moltis provides no native tooling for the body to lean on.

## Not mapped

- **Secret commands**: `draft-self-review`, `gather-review-data`, `review-open-source-attestation`. Their bodies are sops-encrypted (`command.sops`) and never enter the Nix store, so they cannot be rendered as skills.
- **Dispatch-bound commands**: any command with `[compose] agent` set and `caller-context` unset (`agent = "..."` without `caller-context = true`, for example `draft-*`, `create-*`, `post-*`, `review-*`, `work-order-*`). Their bodies assume native Task or Agent sub-agent dispatch wrappers that Moltis does not project.
- **Git, GitHub, and interactive workflow commands**: commands whose bodies reference Git, `gh`, Slack, Herdr, or interactive desktop/CI workflows (for example `make-commit`, `make-pr`, `babysit-pr`, `finish-pr`, `address-code-review`, `implement-task`, and `implement-plan`) stay out of `moltisCommandAllowlist`; Moltis uses the projected `gh`, `review-code`, and `review-code-follow-up` skills instead.

## Preset naming rule

Never name a projected Moltis agent preset `coordinator`, `auxiliary`, `compression`, or `review`. These collide with Moltis built-in presets and the WW-273 TOML lanes, and preset definitions merge over built-ins at load.

## Verification

Preparation does not authorise `just switch-home`. After separate deployment approval, check that agents and skills appear in the Moltis UI.

Validate composed tool instructions for Skrye, Zannah, and Traya. Test deployment and migration with a temporary `HOME`, never the real home directory. These checks need neither activation nor a Rust build. See the [owned-files tests](../assistants/owned-files/README.md) for the safe deployment procedure.

Matrix provisioning runs automatically on Malak. Human login and live messaging checks follow normal deployment.
