# Pi Agent module

Installs [Pi Agent](https://github.com/badlogic/pi-mono), the `pi` coding-agent CLI, for developer-tagged Home Manager users.

The upstream package comes from `inputs.llm-agents.packages.${system}.pi`, matching the other coding-agent packages sourced from `numtide/llm-agents.nix`.

## Behaviour

- Adds a `pi` wrapper to `home.packages`
- Adds `pi-fenced`, which runs the standard `pi` wrapper under the shared [Fence](../fence) permission and isolation policy
- Gates installation with `noughtyLib.userHasTag "developer"`
- Exports `ANTHROPIC_API_KEY` from the sops-nix runtime secret path before execing the Nix-provided Pi binary
- Exports `ANTHROPIC_OAUTH_TOKEN` from Claude Code's local OAuth credentials when available, so quota extensions can query Anthropic plan windows
- Adds a `pi-npm` wrapper backed by Nixpkgs `nodejs`, with npm's global prefix redirected to `~/.pi/agent/npm-global` and routine npm advisory output disabled
- Owns Pi config and resource files through Home Manager:
  - `~/.pi/agent/settings.json`
  - `~/.pi/agent/mcp.json`
  - `~/.pi/agent/extensions/pi-footer.json`
  - `~/.pi/agent/pi-sub-core-settings.json`
  - `~/.pi/agent/extensions/subagent/config.json`
  - `~/.pi/agent/AGENTS.md`
  - `~/.pi/agent/agents/*.md`
  - `~/.pi/agent/prompts/*.md`
  - `~/.pi/agent/skills/*/SKILL.md`
  - `~/.pi/agent/themes/catppuccin-mocha.json`
- Does not enable services
- Does not write literal token material into the Nix store
- Does not run `pi install` during activation

The `llm-agents` package wrapper disables Pi's version check and telemetry at runtime. Pi's own install telemetry is also disabled in `settings.json`.

## Native settings

Home Manager owns `~/.pi/agent/settings.json` completely. Project-specific or mutable package settings should live in `.pi/settings.json`, which Pi merges over the global settings. Nested objects merge.

The managed settings use OpenAI Codex by default:

```json
{
  "defaultProvider": "openai-codex",
  "defaultModel": "gpt-5.6-sol",
  "defaultThinkingLevel": "medium",
  "hideThinkingBlock": true,
  "enabledModels": [
    "anthropic/claude-opus-5",
    "anthropic/claude-sonnet-5",
    "openai-codex/gpt-5.6-sol",
    "openai-codex/gpt-5.6-terra",
    "openai-codex/gpt-5.5",
    "openai-codex/gpt-5.3-codex-spark",
    "openai-codex/gpt-5.4-mini"
  ],
  "theme": "catppuccin-mocha",
  "themes": ["themes/*.json"]
}
```

Compaction and retry are enabled. Retry settings favour longer backoff for transient provider overloads:

```json
{
  "retry": {
    "enabled": true,
    "maxRetries": 5,
    "baseDelayMs": 3000,
    "provider": {
      "maxRetries": 3,
      "maxRetryDelayMs": 120000
    }
  }
}
```

Anthropic can return `overloaded_error` during provider-side capacity pressure. These settings give Pi more time to recover before the error reaches chat. Pi still displays provider errors after retries are exhausted, and the failed request remains recorded in the session logs.

`enableSkillCommands` is enabled so shared skills are invocable as `/skill:<name>`.

## Pinned packages

Pi packages are installed through the Home Manager-owned package setting:

```json
{
  "packages": [
    "npm:pi-mcp-adapter@2.28.0",
    "npm:pi-subagents@0.57.0",
    "npm:pi-lens@4.1.2",
    {
      "source": "npm:typescript@7.0.2",
      "extensions": [],
      "skills": [],
      "prompts": [],
      "themes": []
    },
    "npm:pi-footer@0.5.1",
    "npm:@marckrenn/pi-sub-core@1.5.0",
    "npm:pi-cc-header@1.1.1",
    "npm:@heyhuynhgiabuu/pi-pretty@0.6.24",
    "npm:pi-service-tier@0.3.0",
    "npm:@juicesharp/rpiv-btw@2.7.1",
    "npm:@juicesharp/rpiv-todo@2.7.1"
  ]
}
```

Versioned Pi package specs are pinned and skipped by `pi update`. These packages are user-level JavaScript extensions installed by Pi's npm integration under the user-owned npm prefix. `typescript` supplies the compiler API that `pi-lens` imports at runtime but lists only as a development dependency. Its Pi resources are disabled because it is a runtime dependency, not an extension.

`pi-cc-header` loads from its npm package with `ccHeader.readOnlyConfig` set in the Home Manager-owned `settings.json`. That upstream read-only mode (added in 1.1.1 for declarative setups) stops the extension writing `settings.json`, so header commands such as `/htg` apply for the current session only. It replaces the local writable-state patch that earlier releases needed.

[`pi-pretty`](https://github.com/heyhuynhgiabuu/pi-pretty) re-renders built-in tool output: syntax-highlighted `read` previews, coloured `bash` exit summaries, Nerd Font `ls` icons, and FFF frecency-backed `find`/`grep`. Home Manager owns `~/.pi/agent/pi-pretty.json`, which selects the Catppuccin Shiki theme, keeps Nerd Font icons on, and opts in the `ls` renderer. `pi-fff` must not be installed alongside it because both claim the same built-in tool names. FFF index data lives under `~/.pi/agent/pi-pretty/fff/`.

The `juicesharp/rpiv-mono` extensions add native Pi behaviour:

- `rpiv-btw` performs an explicit side model call using current conversation context
- `rpiv-todo` adds a model-visible todo tool and `/todos` UI

`@juicesharp/rpiv-args` and `@juicesharp/rpiv-i18n` are not installed. Pi natively substitutes `$1`/`$@`/`$ARGUMENTS` inside prompt templates and appends trailing arguments as a follow-up `User:` message after skill bodies. `rpiv-args` extended placeholder substitution into skill bodies as well, which silently rewrites incidental `$1` and `$NNNN` matches inside reference content (for example SQL placeholder syntax and currency strings in the security skills); the Pi-native split is preferred.

## Status line

[`pi-footer`](https://github.com/wobondar/pi-footer) replaces the older `pi-bar` footer. Home Manager owns `~/.pi/agent/extensions/pi-footer.json` and renders one compact line:

```text
 model thinking · Fast state · dir · quota windows · context window · Context N% used
```

Quota data comes from [`@marckrenn/pi-sub-core`](https://github.com/marckrenn/pi-sub). `sub-core` auto-detects the active provider from the current model. The local `quota-status` extension publishes the first two quota windows through Pi's extension status API, which `pi-footer` displays when data is available. Anthropic can provide 5h and weekly windows. OpenAI Codex provides its primary and secondary windows.

The footer uses the same Catppuccin colour roles as `ccstatusline`: model and thinking yellow, fast state mauve, current directory green, quotas red, and context peach. A white Pi glyph (`nf-fae-pi`) leads the line so the Pi footer is distinguishable from the Codex status line at a glance.

`quota-status` uses stable window labels where possible and displays remaining quota, not used quota, so Anthropic usually appears as:

```text
 claude-opus-5 high · Fast off · project · 5h 93% · weekly 96% · 1.0M window · Context 3.1% used
```

Home Manager also owns `~/.pi/agent/pi-sub-core-settings.json` to refresh quota data every five seconds and on turn start. `sub-core` renders cached state first, so the quota segment can appear a few seconds after the footer itself. If Anthropic returns only the 5h window, `quota-status` mirrors the Claude Code statusline helper by treating the missing weekly bucket as 100% remaining. Other providers show only the usable windows they return. `quota-status` keeps the last valid value for the active provider when `sub-core` emits a transient empty update.

Anthropic quota data requires an OAuth token, not the `ANTHROPIC_API_KEY` used for model calls. The `pi` wrapper reads `~/.claude/.credentials.json` or `$CLAUDE_CONFIG_DIR/.credentials.json` and exports `ANTHROPIC_OAUTH_TOKEN` when the Claude Code login token has the `user:profile` scope. Without that local login, the Anthropic quota segment stays hidden. OpenAI Codex quota data comes from Pi's `auth.json`, Codex environment variables, or the legacy Codex auth file as supported by `sub-core`.

[`pi-service-tier`](https://github.com/mavam/pi-service-tier) provides `/fast` and `/service-tier` for provider service tiers (OpenAI and Codex flex/priority, Anthropic priority/standard). It persists to its own `~/.pi/agent/service-tier.json` and never writes `settings.json`. It publishes its state only as `pi-fancy-footer` widget events, so the local `service-tier-status` extension bridges those events into the `noughty-service-tier:status` key, which the footer shows as a yellow `Fast on` or `Fast off` segment after the thinking level. The bridge sends the `pi-fancy-footer:ready` handshake at session start so the load order does not matter. Do not install `pi-fancy-footer` alongside the bridge, because both would answer the same handshake.

## Local extensions

Home Manager deploys local Pi extensions under `~/.pi/agent/extensions/`.

`provider-router` lives at `~/.pi/agent/extensions/provider-router/`. It routes
Pi `subagent` tool calls to provider-specific models declared in assistant
`header.pi.yaml` files.

`quota-status` lives at `~/.pi/agent/extensions/quota-status/`. It listens to
`sub-core` quota updates and publishes the compact quota segment consumed by
`pi-footer`.

`service-tier-status` lives at `~/.pi/agent/extensions/service-tier-status/`.
It mirrors `pi-service-tier`'s fast-mode widget events into the
`noughty-service-tier:status` key consumed by `pi-footer`.

`hardware-cursor` lives at `~/.pi/agent/extensions/hardware-cursor/`. Pi's
editor always paints its own inverse-block cursor, and `showHardwareCursor`
only un-hides the terminal cursor on top of it. While `showHardwareCursor` is
true in `settings.json`, this extension strips the inverse block from the
editor render so the terminal emulator draws the only cursor. Set
`showHardwareCursor` to false to make the extension inert and restore stock
behaviour. When a Pi update changes the cursor escape codes, the strip finds
no match and the stock double cursor returns, so the editor never breaks.

`prompt-template-display` lives at
`~/.pi/agent/extensions/prompt-template-display/`. In TUI mode, it discovers
file-backed commands that Pi reports with the `prompt` source. It displays only
the original slash invocation while it reads and expands the current
`sourceInfo.path` with Pi 0.83.0 argument rules. For an idle prompt, it stores
one raw command and expansion, sends the raw command as a user message, and
returns a hidden marker from `before_agent_start`. The `context` hook uses the
marker to replace the nearest earlier user message text with the expansion. It
keeps attached images and removes the marker. Steer and follow-up input keep the
hidden custom message path because streaming input does not run
`before_agent_start`. SDK prompt commands pass through because
their source paths can be virtual.

Run the focused tests with:

```console
node --experimental-loader ./home-manager/_mixins/agentic/pi/extensions/prompt-template-display/test-loader.mjs --test home-manager/_mixins/agentic/pi/extensions/prompt-template-display/index.test.ts
```

`communication-rules` lives at `~/.pi/agent/extensions/communication-rules/`.
It receives the complete body of the `communication-rules` skill without
frontmatter. Pi also installs the skill under `~/.pi/agent/skills/`, while
`AGENTS.md` and generated agents load it by name. The extension uses Pi's native
`context` event for model-call injection, `input` for non-blocking reminders,
`tool_call` for outgoing writes, edits, Bash prose side effects, and post
bodies, `message_end` for final-message correction, and `tool_result` for
displayed `subagent` tool results.

Pi can stream text before `message_end`. Agent Tripwire treats that as an
accepted v1 platform limit: final-message correction still runs at
`message_end`, but earlier streamed text may already be visible.

After Home Manager changes local Pi extensions, run `/reload` in an existing Pi
session or restart Pi so it discovers the deployed files.

There is no Pi command, flag, environment variable, allow rule, or prompt escape
that bypasses Tripwire. Operator recovery is still available through normal
config disablement, such as `disableAllHooks`, or by rebuilding without the
Agent Tripwire mixin.

Managed files:

- `~/.pi/agent/extensions/provider-router/index.ts`
- `~/.pi/agent/extensions/provider-router/types.d.ts`
- `~/.pi/agent/extensions/provider-router/agents.json`
- `~/.pi/agent/extensions/provider-router/README.md`
- `~/.pi/agent/extensions/provider-router/LICENSE`
- `~/.pi/agent/extensions/hardware-cursor/index.ts`
- `~/.pi/agent/extensions/prompt-template-display/index.ts`
- `~/.pi/agent/extensions/prompt-template-display/types.d.ts`
- `~/.pi/agent/extensions/quota-status/index.ts`
- `~/.pi/agent/extensions/service-tier-status/index.ts`
- `~/.pi/agent/extensions/communication-rules/index.ts`
- `~/.pi/agent/extensions/communication-rules/config.json`

See
[`extensions/provider-router/README.md`](extensions/provider-router/README.md)
for declaration rules, runtime constraints, and verification commands.

## Theme

Pi supports JSON themes loaded from `~/.pi/agent/themes/*.json`, package theme directories, or the `themes` setting.

This module writes `~/.pi/agent/themes/catppuccin-mocha.json` from the repository's `catppuccinPalette` and sets Pi's default theme to `catppuccin-mocha`. No third-party theme package is installed.

## Authentication

`secrets/ai.yaml` provides `ANTHROPIC_API_KEY`.

The `pi` wrapper reads `config.sops.secrets.ANTHROPIC_API_KEY.path` at runtime and exports the key only for the Pi process. When Claude Code OAuth credentials exist locally, it also exports `ANTHROPIC_OAUTH_TOKEN` for Pi's quota extensions. The managed `settings.json` and all managed Pi resource files contain no literal secret values.

This module does not manage `~/.pi/agent/auth.json`. Pi can still create that file through `/login` for subscription providers or manually entered API keys.

## Fenced mode

Use `pi-fenced` for the Fence-isolated entry point. It runs the same Home
Manager-managed `pi` wrapper as plain `pi`, so the Anthropic key handling and
Pi configuration path remain identical while Fence provides the managed
filesystem, network, and command policy.

## MCP

Pi MCP support is provided by [pi-mcp-adapter](https://github.com/nicobailon/pi-mcp-adapter), installed through the pinned package setting.

Pi imports the canonical server definitions from `../mcp/servers.nix`, then renders a self-contained `~/.pi/agent/mcp.json`. Default servers do not need the Claude Code `~/.config/mcp/mcp.json` template for Pi.

`~/.pi/agent/mcp.json` is Pi-specific and is rendered through sops-nix because some server entries include auth headers. It carries conservative global adapter settings:

- `directTools = false`
- `disableProxyTool = false`
- `autoAuth = false`
- `sampling = false`
- `samplingAutoApprove = false`

That keeps the adapter's proxy tool enabled, disables direct tools by default, and prevents MCP servers from sampling through Pi. Project-level `.pi/mcp.json` files can override these settings deliberately.

Pi's adapter supports per-server `enabled` flags. Disabled servers remain visible in Pi's MCP TUI and can be toggled on without a Home Manager rebuild.

Pi follows OpenCode's enabled-by-default MCP preference through `enabled` and `directTools`:

| Server     | Pi default                     |
| ---------- | ------------------------------ |
| `context7` | Enabled, direct tools promoted |
| `exa`      | Enabled, direct tools promoted |
| `linear`   | Enabled, direct tools promoted |

The Pi-specific file emits full server entries, not partial overrides, because `pi-mcp-adapter` shallow-merges MCP config files by server name. A partial entry that only set `directTools` would replace the shared command, args, URL, or auth fields.

## Subagents

[`pi-subagents`](https://github.com/nicobailon/pi-subagents) is installed through the pinned package setting.

The extension config is managed at `~/.pi/agent/extensions/subagent/config.json`:

```json
{
  "asyncByDefault": false,
  "forceTopLevelAsync": false,
  "parallel": {
    "maxTasks": 4,
    "concurrency": 2
  },
  "defaultSessionDir": "~/.pi/agent/sessions/subagent",
  "maxSubagentDepth": 1,
  "intercomBridge": {
    "mode": "off"
  }
}
```

`maxSubagentDepth = 1` allows explicit direct subagent use from top-level Pi sessions. Generated assistant agents do not add a per-agent `maxSubagentDepth` by default; set `maxSubagentDepth` in an individual `header.pi.yaml` only when that agent needs its own depth limit.

The builtin `researcher` agent is disabled by default because it requires `pi-web-access`, which this module does not install.

## Assistant mapping

Source content comes from `home-manager/_mixins/agentic/assistants`. Rendering for Pi lives in `home-manager/_mixins/agentic/assistants/default.nix`; this module consumes the generated Home Manager file entries.

| Source                                          | Pi destination                     | Mapping                                                                                                                                                                                                                                                                                                            |
| ----------------------------------------------- | ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `instructions/global.md`                        | `~/.pi/agent/AGENTS.md`            | Global context file loaded by Pi                                                                                                                                                                                                                                                                                   |
| `agents/<name>/prompt.md` and `description.txt` | `~/.pi/agent/agents/<name>.md`     | Pi subagent Markdown with YAML frontmatter                                                                                                                                                                                                                                                                         |
| `agents/<name>/commands/<command>/prompt.md`    | `~/.pi/agent/prompts/<command>.md` | Prompt template that asks Pi to call the matching subagent. The owning agent is pinned by a `Use the subagent tool to launch the <name> agent` prelude in the body, not by the filename. Evaluation fails if two source directories (across agents or with standalone commands) produce the same `<command>` name. |
| `commands/<command>/prompt.md`                  | `~/.pi/agent/prompts/<command>.md` | Native Pi prompt template                                                                                                                                                                                                                                                                                          |
| `skills/<name>/`                                | `~/.pi/agent/skills/<name>/`       | Symlinked Agent Skills directory                                                                                                                                                                                                                                                                                   |

Traya is the unnamed default prompt through `instructions/global.md`. She is not emitted as a named Pi subagent.

Pi agent frontmatter is sourced from `header.pi.yaml`. When the file is absent the agent inherits three defaults: `systemPromptMode: append`, `inheritProjectContext: false`, and `inheritSkills: true`. `name` and `description` are injected automatically from the directory name and `description.txt`. Per-agent values for `model`, `thinking`, `tools`, `defaultContext`, `maxSubagentDepth`, and other Pi-native fields go in `header.pi.yaml` alongside `header.claude.yaml` and `header.codex.toml`. Prompt templates use `header.pi.yaml` for `argument-hint` rather than reading the Claude header.

Pi subagent Markdown supports explicit `tools` allowlists through Pi-native
frontmatter when an individual agent needs a narrower tool surface.
