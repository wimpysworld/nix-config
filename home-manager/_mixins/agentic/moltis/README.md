# Moltis projection

The assistants consumer projects agents, skills, and global instructions into `~/.moltis` for Moltis (tag 20261023.01). The shared gate requires user `martin`, Linux or Darwin, and host tag `moltis`: `skrye`, `zannah`, and `momin`. Momin replaces Malak as Traya's host.

The owned-files deployer tracks `~/.moltis` as an ownership root. Personal, command-derived, sops-rendered secret, and Chainguard skills deploy there as regular files.

> [!IMPORTANT]
> This change prepares configuration only. Do not activate services, create accounts, change DNS, write secrets, or sign in without separate approval.

## Traya on Momin

Traya uses the ChatGPT subscription through `openai-codex::gpt-6-astra` for chat, with medium effort in the `coordinator` and `review` presets. The `auxiliary` and `compression` presets use `openai-codex::gpt-6-luna@reasoning-high` with `reasoning_effort = "high"`. Title generation and heartbeat use the same Luna model with high effort through Moltis's `@reasoning-high` model suffix, independently of presets.

The `auxiliary.compaction` and `auxiliary.vision` settings also select Luna with high effort, but Moltis 20261023.01 does not connect those settings to callers. Structured compaction still uses the session provider. The [pinned provider registry](https://github.com/moltis-org/moltis/blob/20261023.01/crates/providers/src/registry/registration.rs) applies reasoning suffixes when it resolves models.

The installed Codex catalogue confirms `gpt-6-luna` and high effort. Live availability under the subscription remains unverified. No API-key billing fallback is configured.

After approval and deployment, sign in locally on Momin as the same user that runs Moltis:

```sh
moltis auth login --provider openai-codex
```

Alternatively, connect OpenAI Codex in the Moltis settings UI. [Upstream provider documentation](https://github.com/moltis-org/moltis/blob/20261023.01/docs/src/providers.md) describes OAuth sign-in. OAuth credentials are unmanaged runtime state, not Nix configuration or SOPS secrets. Do not copy tokens into this repository.

Gemini still supplies text-to-speech, speech-to-text, and embeddings. Traya therefore still requires `GEMINI_API_KEY`, although the Gemini chat provider is disabled. Traya retains `TELEGRAM_BOT_TRAYA` and `SOUL_TRAYA` from `secrets/moltis.yaml`.

Momin uses the logged-in user's LaunchAgent, labelled `org.moltis.gateway`. It starts at login and restarts on failure. It is not a boot daemon. An always-on Mac still needs a user login and readable sops-nix secrets. The wrapper waits briefly for secrets and fails if they remain unavailable.

On Darwin, Home Manager also restarts Moltis after synchronous SOPS rendering and owned assistant deployment when its public change token changes. The token covers the TOML template's store path, the launcher's store path, and the public MCPorter configuration text. It also covers the configured keys and encrypted source paths for Moltis environment secrets. Changes anywhere in those encrypted source files trigger a restart, including credential rotations. The hook never reads or hashes decrypted values. Other assistant resource changes and unmanaged OAuth credentials do not independently trigger this hook. Home Manager still handles binary and LaunchAgent changes.

The first activation restarts Moltis because no token exists. The hook saves `~/.local/state/moltis/activation-token` (under `xdg.stateHome`) atomically with mode `0600` only after a successful restart. Failed rendering stops activation before the hook. Failed restarts leave the previous token intact for a retry. If the GUI login domain is absent, log in and repeat activation. The restart hook and synchronous refresh respect Home Manager's dry-run mode.

Use `moltis-log` to read `${XDG_STATE_HOME}/moltis/daemon.stdout.log` and `daemon.stderr.log`. With the default state directory, both files are under `~/.local/state/moltis/`. Linux retains `moltis.service` and its journal alias.

Fence command controls on Darwin are weaker than the Linux controls. The user accepts that difference. Native Darwin build and runtime validation remain pending. Build on Momin after approval, without an automatic SSH runtime test.

## Provider, presets, and Telegram channel

`default.nix` renders `~/.config/moltis/moltis.toml` through a sops template. Skrye and Zannah use the Gemini defaults below. Traya uses the Astra and Luna routing described above:

- `coordinator` (`delegate_only = false`) and `review` presets use `gemini::gemini-4-argon`.
- `auxiliary` and `compression` presets use `gemini::gemini-3.8-flash`.
- `identity` sets `name` to `agentName` (`traya` on `momin`, otherwise `host.name`), and `user` sets `name = "Martin"`, `timezone = "Europe/London"`, and `write_mode = "off"`.
- `auxiliary` routes `compaction`, `title_generation`, and `vision` to `gemini::gemini-3.8-flash`, and `chat.compaction.mode` uses `"structured"`.
- `skills.enable_self_improvement` is `false`.
- `tools.agent_max_auto_continues` is `0`, which disables auto-continue `done` replies for all agents, so heartbeat runs that call several tools still return `HEARTBEAT_OK`. `tools.exec` sets `approval_mode = "never"` and `sandbox.mode = "off"` (Moltis runs inside `moltis-fenced`), and `tools.fs` sets `workspace_root` to `$HOME` with `track_reads = true` and `must_read_before_write = true`.
- `moltis-in-fence` exports per-agent GitHub and Git identity variables (`GH_TOKEN`, `GIT_AUTHOR_NAME`, `GIT_COMMITTER_NAME`, `GIT_AUTHOR_EMAIL`, and `GIT_COMMITTER_EMAIL`), disables commit and tag signing (`commit.gpgSign = false`, `tag.gpgSign = false`) via `GIT_CONFIG_*`, and rewrites GitHub SSH URLs (`git@github.com:` and `ssh://git@github.com/`) to `https://github.com/` authenticated through `gh auth git-credential`.
- `memory` uses `provider = "custom"` with `base_url = "https://generativelanguage.googleapis.com/v1beta/openai"`, `model = "gemini-embedding-2"`, and `api_key = "${GEMINI_API_KEY}"`.
- `heartbeat` runs every `30m` on `gemini::gemini-3.8-flash` (`sandbox_enabled = false`, `deliver = true`) and delivers to `channel = "moltis"` (`to = "${TELEGRAM_ALLOWED_USERS}"`).
- `voice.tts` selects the `openai` provider pointed at a local OpenAI-compatible shim (`base_url = "http://127.0.0.1:13139/v1"`) started inside `moltis-fenced`, with `model = "gemini-3.8-flash-tts"`. Traya on `momin` uses `voice = "en-gb-tutor-13"`. `skrye` uses `voice = "en-gb-commercial-6"` and `zannah` uses `voice = "en-gb-concierge-6"`. The shim reads `GEMINI_API_KEY` from the sops secret file, calls Google's `gemini-3.8-flash-tts` `generateContent` endpoint, and transcodes the returned WAV audio to Ogg Opus (`audio/ogg`) via `ffmpeg` so Moltis sends native Telegram voice notes without setting `voice.tts.openai.api_key`.
- `moltis-telegram-voice` (`<text>` or `--body-file <path>`) is installed in `home.packages` and `moltis-in-fence` `runtimeInputs`. It posts text to the local TTS shim (`http://127.0.0.1:13139/v1/audio/speech`) for Ogg Opus synthesis and uploads the voice note to Telegram `sendVoice` using `TELEGRAM_BOT_TOKEN` and `TELEGRAM_ALLOWED_USERS`.
- `voice.stt` selects the `whisper` provider pointed at the same local shim (`base_url = "http://127.0.0.1:13139/v1"`) with `model = "gemini-3.8-flash"`. On `POST /v1/audio/transcriptions`, the shim parses the `multipart/form-data` audio upload, normalizes or transcodes unsupported formats to `audio/ogg` via `ffmpeg`, calls `gemini-3.8-flash:generateContent` with `GEMINI_API_KEY`, and returns `{"text": "..."}` without setting `voice.stt.whisper.api_key`.
- `channels.telegram.moltis` defaults to `gemini-4-argon` on `gemini` with `dm_policy = "allowlist"`, `group_policy = "disabled"`, `stream_mode = "edit_in_place"`, `stream_min_initial_chars = 30`, `edit_throttle_ms = 1000`, `reply_to_message = true`, and `otp_self_approval = false`.

The `[env]` table injects sops placeholders into the Moltis process environment at render time:

| Variable                 | Sops file             | Key                                |
| ------------------------ | --------------------- | ---------------------------------- |
| `GEMINI_API_KEY`         | `secrets/ai.yaml`     | `GEMINI_API_KEY`                   |
| `TELEGRAM_BOT_TOKEN`     | `secrets/moltis.yaml` | `TELEGRAM_BOT_<AGENT>`             |
| `TELEGRAM_ALLOWED_USERS` | `secrets/moltis.yaml` | `TELEGRAM_OPERATOR_IDS`            |
| `GH_TOKEN`               | `secrets/moltis.yaml` | `GITHUB_TOKEN_<AGENT>`             |
| `GIT_AUTHOR_EMAIL`       | `secrets/moltis.yaml` | `GITHUB_EMAIL_<AGENT>`             |
| `CONTEXT7_API_KEY`       | `secrets/mcp.yaml`    | `CONTEXT7_API_KEY`                 |
| `LINEAR_API_KEY`         | `secrets/linear.yaml` | `chainguard` or `wimpysworld`      |

## MCP through MCPorter

Skrye, Zannah, and Traya use MCPorter through `exec` for Model Context Protocol (MCP) access, in main and spawned agents. All three receive the five configured servers, including Linear. Other clients keep their native MCP configuration unchanged.

Nix generates a dedicated MCPorter configuration from the Moltis-filtered shared registry, with `imports = []`. Its path is `moltis/mcporter.json` relative to `config.xdg.configHome`. The runtime supplies its absolute path through `MCPORTER_CONFIG` and explicitly selects the pinned MCPorter binary. No editor configuration imports or automatic OAuth login are part of this route. Credentials reach MCPorter through SOPS-managed environment variables and runtime wrappers, never command arguments.

Moltis no longer registers these servers directly with the model. This avoids exposing Linear's URI tool schemas to Traya's Codex provider. Main and spawned agents use the same CLI recipe in [TOOLS.md](TOOLS.md). The CLI adds process and connection work. Latency is unmeasured, and no token savings or performance measurements are established.

An empty TOML server table is insufficient for migration: persisted `mcp-servers.json` entries override the empty table. Before gateway startup, the migration helper disables persisted native entries but preserves their definitions and unknown fields. It creates `mcp-servers.json.pre-mcporter.bak` beside the registry without overwriting an existing backup. Both files use mode `0600`, and registry replacement is atomic. The helper rejects invalid data, symlinks, unsafe ownership, and a data directory that other users can write. These repository changes prepare all three agents together.

The main agent's `tools.policy.deny = [ "mcp_*" ]` filters native MCP tools. Generated Markdown presets deny the five exact native management tools: `mcp_list`, `mcp_add`, `mcp_remove`, `mcp_status`, and `mcp_restart`. TOML presets, including the retained upstream `research` and `coder` presets, also receive these denies and CLI instructions. This is not a global MCP shutdown or a hard security boundary. Spawned agents do not inherit that global policy. Their preset denies and explicit parent briefings must retain the CLI route and native management restrictions. An explicit non-empty `deny_tools` list replaces preset defaults, so callers must preserve the complete preset denylist rather than supply a partial override.

Keep configuration and instructions in their Nix-managed sources, not installed files. Use [TOOLS.md](TOOLS.md) for focused discovery, JSON calls, output bounds, and spawn briefings. If a write times out, its outcome is unknown. Verify remote state through an authorised read before any retry, and never replay a write automatically.

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
| `~/.moltis/SOUL.md`                  | `assistant-moltis-soul` sops template (`SOUL_<AGENT>` + `SOUL_ALL`)     | Agent soul from `secrets/moltis.yaml` followed by `SOUL_ALL`, deployed via `ownedFiles` (`kind = "file"`, mode `0600`).         |
| `~/.moltis/agents/main/SOUL.md`      | `assistant-moltis-soul` sops template (`SOUL_<AGENT>` + `SOUL_ALL`)     | Same soul deployed into the `main` agent workspace via `ownedFiles` so Moltis's first-run seed copy never goes stale.           |
| `~/.moltis/USER.md`                  | `assistant-moltis-user` sops template (`USER` in `secrets/moltis.yaml`) | User profile deployed via `ownedFiles` (`kind = "file"`, mode `0600`).                                                          |
| `~/.moltis/agents/main/USER.md`      | `assistant-moltis-user` sops template (`USER` in `secrets/moltis.yaml`) | Same user profile deployed into the `main` agent workspace via `ownedFiles`.                                                    |
| `~/.moltis/HEARTBEAT.md`             | `moltis/HEARTBEAT.md` (per-host schedule substituted)                   | 30-minute GitHub notification inbox triage plus weekly maintenance sweep (`skrye` Wednesday, `zannah` Saturday, `traya` Sunday). |
| `~/.moltis/agents/main/HEARTBEAT.md` | `moltis/HEARTBEAT.md` (per-host schedule substituted)                   | Same heartbeat specification deployed into the `main` agent workspace via `ownedFiles` (`kind = "file"`, mode `0600`).          |

Generated agent frontmatter contains `name`, `theme`, and `deny_tools`. Moltis has no `description` field, so `theme` carries the agent description (Moltis `AgentFrontmatter`, `crates/config/src/agent_defs.rs`). The body becomes the preset's `system_prompt_suffix`.

Moltis's `read_skill` tool (`crates/tools/src/skill_tools/read_ops.rs`) rejects symlinked skill directories and rejects sidecar files whose canonical path resolves outside the skill directory. Therefore, all skills under `~/.moltis/skills/<name>/` (project `SKILL.md` files, recursive sidecar files, command-derived skills, sops-rendered secret skills, and optional Chainguard skills) deploy through `ownedFiles` as real directories and regular files (`kind = "file"`, mode `0600`).

## Tool instructions and ownership

Edit the repository's [TOOLS.md](TOOLS.md), not either installed copy. Nix replaces its single `@ENVIRONMENT@` marker with public host and provider facts. The generated section uses the configured home directory for Linux or Darwin paths and describes the existing Fence restrictions. It grants no broader access. Gemini's parser restriction applies only to Gemini, not Traya's Codex chat provider. All three agents access Linear through MCPorter, as described above.

Only the Tools section moves out of Moltis's `AGENTS.md`. Role, workflow, Safety, and house-style instructions remain in `AGENTS.md` and its composition.

For normal chat, Moltis reads profile `TOOLS.md` first and falls back to the root copy. It injects exactly one copy on each request. A deployed tool-instruction change needs no daemon restart for this path. Other request paths remain unverified. Nix activation owns both generated files. Upstream Moltis seeds a missing root `TOOLS.md` from its default comment-only content and copies the root file into a missing main workspace copy. Startup does not overwrite existing files.

Migration accepts the known previous `AGENTS.md` hash and the upstream comment-only `TOOLS.md` seed. Unknown custom content, including an unowned empty file, remains untouched and causes a deployment conflict. Web UI edits do not bypass ownership checks and can cause the same conflict. Keep the repository source canonical and review conflicts before activation.

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
