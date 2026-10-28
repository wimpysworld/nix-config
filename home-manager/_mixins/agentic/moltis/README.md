# Moltis projection

The assistants consumer projects agents, skills, and global instructions into `~/.moltis` for the Moltis client (tag 20261023.01). The gate is `moltisEnabled` in `../assistants/default.nix`, which matches the host gate in `mcp/default.nix`: user `martin`, Linux host, host tag `moltis` (`skrye` and `zannah`). The owned-files deployer tracks `~/.moltis` as an ownership root so its sops-rendered secret skills and managed links deploy there.

## Provider, presets, and Telegram channel

`default.nix` renders `~/.config/moltis/moltis.toml` through a sops template. It enables the `gemini` provider with `gemini-4-argon` and `gemini-3.8-flash`:

- `coordinator` and `review` presets use `gemini::gemini-4-argon`.
- `auxiliary` and `compression` presets use `gemini::gemini-3.8-flash`.
- `identity` sets `name` to the host name, and `user` sets `name = "Martin"` and `timezone = "Europe/London"`.
- `auxiliary` routes `compaction`, `title_generation`, and `vision` to `gemini::gemini-3.8-flash`, and `chat.compaction.mode` uses `"structured"`.
- `skills.enable_self_improvement` is `false`.
- `tools.exec` sets `approval_mode = "never"` and `sandbox.mode = "off"` (Moltis runs inside `moltis-fenced`), and `tools.fs` sets `workspace_root` to `$HOME` with `track_reads = true` and `must_read_before_write = true`.
- `memory` uses `provider = "custom"` with `base_url = "https://generativelanguage.googleapis.com/v1beta/openai"`, `model = "gemini-embedding-2"`, and `api_key = "${GEMINI_API_KEY}"`.
- `heartbeat` runs every `30m` on `gemini::gemini-3.8-flash` (`sandbox_enabled = false`, `deliver = true`) and delivers to `channel = "moltis"` (`to = "${TELEGRAM_HOME_CHANNEL}"`).
- `voice.tts` selects the `openai` provider pointed at a local OpenAI-compatible shim (`base_url = "http://127.0.0.1:13132/v1"`) started inside `moltis-fenced`, with `model = "gemini-3.8-flash-tts"`. `skrye` uses `voice = "en-gb-assistant-9"` and `zannah` uses `voice = "en-gb-commercial-6"`. The shim reads `GEMINI_API_KEY` from the sops secret file, calls Google's `gemini-3.8-flash-tts` `generateContent` endpoint, and transcodes the returned WAV audio to Ogg Opus (`audio/ogg`) via `ffmpeg` so Moltis sends native Telegram voice notes without setting `voice.tts.openai.api_key`.
- `voice.stt` selects the `whisper` provider pointed at the same local shim (`base_url = "http://127.0.0.1:13132/v1"`) with `model = "gemini-3.8-flash"`. On `POST /v1/audio/transcriptions`, the shim parses the `multipart/form-data` audio upload, normalizes or transcodes unsupported formats to `audio/ogg` via `ffmpeg`, calls `gemini-3.8-flash:generateContent` with `GEMINI_API_KEY`, and returns `{"text": "..."}` without setting `voice.stt.whisper.api_key`.
- `channels.telegram.moltis` defaults to `gemini-4-argon` on `gemini` with `dm_policy = "allowlist"`, `group_policy = "allowlist"`, `mention_mode = "always"`, `untrusted_audience = "trusted"`, `untrusted_tools = "policy"`, and `otp_self_approval = false`.

The `[env]` table injects sops placeholders into the Moltis process environment at render time:

| Variable                 | Sops file             | Key                                |
| ------------------------ | --------------------- | ---------------------------------- |
| `GEMINI_API_KEY`         | `secrets/ai.yaml`     | `GEMINI_API_KEY`                   |
| `TELEGRAM_BOT_TOKEN`     | `secrets/herdr.yaml`  | `TELEGRAM_BOT_<HOST>`              |
| `TELEGRAM_HOME_CHANNEL`  | `secrets/herdr.yaml`  | `TELEGRAM_CHAT_ID_<HOST>`          |
| `TELEGRAM_ALLOWED_USERS` | `secrets/herdr.yaml`  | `TELEGRAM_OPERATOR_IDS`            |
| `CONTEXT7_API_KEY`       | `secrets/mcp.yaml`    | `CONTEXT7_API_KEY`                 |
| `LINEAR_API_KEY`         | `secrets/linear.yaml` | `chainguard` or `wimpysworld`      |

## Projection surfaces

| Destination                  | Source                                                     | Notes                                                                                                     |
| ---------------------------- | ---------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `~/.moltis/agents/<name>.md` | `agents/<name>/prompt.md` + `compose.readHeader`           | One file per coding agent, file by file. Moltis writes runtime workspaces into `~/.moltis/agents/`.        |
| `~/.moltis/skills/<name>/SKILL.md` | `compose.composeSkillsFor "moltis"`, allowlisted commands | Skill directories with `SKILL.md`; Moltis discovers skills one level deep and never writes inside a personal skill. |
| `~/.moltis/AGENTS.md`        | `instructions/global.md` + `compose.houseStyleBody`        | Plain Markdown, no frontmatter.                                                                            |

Agent frontmatter is `name` and `theme`; Moltis has no `description` field, so `theme` carries the agent description (Moltis `AgentFrontmatter`, `crates/config/src/agent_defs.rs`). The body becomes the preset's `system_prompt_suffix`.

Skill symlinks are safe because the skills manifest and registry installs live beside, not inside, the skills directory: `skills-manifest.json` sits at `~/.moltis/skills-manifest.json` (`crates/skills/src/manifest.rs`) and registry installs go to `~/.moltis/installed-skills/`, so nothing writes inside a personal `skills/<name>/` directory. Command-derived skills deploy as regular text files at `~/.moltis/skills/<name>/SKILL.md` rather than symlinks; their bodies are public command markdown.

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
- **Dispatch-bound commands**: any command with `[compose] agent` set and `caller-context` unset (`agent = "..."` without `caller-context = true`, for example `draft-*`, `create-*`, `post-*`, `review-*`, `work-order-*`, `make-commit`, `make-pr`). Their bodies assume native Task, Agent, or `spawn_agent` tooling that Moltis does not project.
- **Desktop and CI commands**: commands that assume an interactive desktop or CI context, for example `babysit-pr`, `finish-pr`, `address-code-review`, `implement-task`, and `implement-plan`.

## Preset naming rule

Never name a projected Moltis agent preset `coordinator`, `auxiliary`, `compression`, or `review`. These collide with Moltis built-in presets and the WW-273 TOML lanes, and preset definitions merge over built-ins at load.

## Verification

After `just switch-home` on the moltis-tagged host, agents and skills appear in the Moltis UI.
