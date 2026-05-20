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

The managed settings use Anthropic by default:

```json
{
  "defaultProvider": "anthropic",
  "defaultModel": "claude-opus-4-7",
  "defaultThinkingLevel": "high",
  "hideThinkingBlock": true,
  "enabledModels": [
    "anthropic/claude-opus-4-7",
    "anthropic/claude-sonnet-4-6",
    "anthropic/claude-haiku-4-5"
  ],
  "theme": "catppuccin-mocha",
  "themes": [
    "themes/*.json"
  ]
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
    "npm:pi-mcp-adapter@2.6.1",
    "npm:pi-subagents@0.24.3",
    "npm:pi-lens@3.8.44",
    "npm:pi-footer@0.3.0",
    "npm:@marckrenn/pi-sub-core@1.5.0",
    {
      "source": "npm:pi-logo@1.0.0",
      "extensions": []
    },
    "npm:@juicesharp/rpiv-btw@1.10.2",
    "npm:@juicesharp/rpiv-todo@1.10.2"
  ]
}
```

Versioned Pi package specs are pinned and skipped by `pi update`. These packages are user-level JavaScript extensions installed by Pi's npm integration under the user-owned npm prefix. `pi-logo` is installed with its package extension disabled so the local `pi-logo-filter` wrapper can constrain startup logos while reusing upstream rendering code.

`pi-logo-filter` keeps only `logo-001` through `logo-009` on random. These are the compact line-art logos that animate with Pi theme colours.

The `juicesharp/rpiv-mono` extensions add native Pi behaviour:

- `rpiv-btw` performs an explicit side model call using current conversation context
- `rpiv-todo` adds a model-visible todo tool and `/todos` UI

`@juicesharp/rpiv-args` and `@juicesharp/rpiv-i18n` are not installed. Pi natively substitutes `$1`/`$@`/`$ARGUMENTS` inside prompt templates and appends trailing arguments as a follow-up `User:` message after skill bodies. `rpiv-args` extended placeholder substitution into skill bodies as well, which silently rewrites incidental `$1` and `$NNNN` matches inside reference content (for example SQL placeholder syntax and currency strings in the security skills); the Pi-native split is preferred.

## Status line

[`pi-footer`](https://github.com/wobondar/pi-footer) replaces the older `pi-bar` footer. Home Manager owns `~/.pi/agent/extensions/pi-footer.json` and renders one compact line:

```text
provider/model · thinking · cwd · quota windows · context window · Context N% used
```

Quota data comes from [`@marckrenn/pi-sub-core`](https://github.com/marckrenn/pi-sub). `sub-core` auto-detects the active provider from the current model. The local `quota-status` extension publishes the first two quota windows through Pi's extension status API, which `pi-footer` displays when data is available. Anthropic can provide 5h and weekly windows. OpenAI Codex provides its primary and secondary windows.

The footer uses the same Catppuccin colour roles as `ccstatusline`: model yellow, thinking mauve, current directory green, quotas red, and context peach.

`quota-status` uses stable window labels where possible and displays remaining quota, not used quota, so Anthropic usually appears as:

```text
anthropic/claude-opus-4-7 · high · ~/path/project · 5h 93% · weekly 96% · 1.0M window · Context 3.1% used
```

Home Manager also owns `~/.pi/agent/pi-sub-core-settings.json` to refresh quota data every five seconds and on turn start. `sub-core` renders cached state first, so the quota segment can appear a few seconds after the footer itself. If Anthropic returns only the 5h window, `quota-status` mirrors the Claude Code statusline helper by treating the missing weekly bucket as 100% remaining. Other providers show only the usable windows they return. `quota-status` keeps the last valid value for the active provider when `sub-core` emits a transient empty update.

Anthropic quota data requires an OAuth token, not the `ANTHROPIC_API_KEY` used for model calls. The `pi` wrapper reads `~/.claude/.credentials.json` or `$CLAUDE_CONFIG_DIR/.credentials.json` and exports `ANTHROPIC_OAUTH_TOKEN` when the Claude Code login token has the `user:profile` scope. Without that local login, the Anthropic quota segment stays hidden. OpenAI Codex quota data comes from Pi's `auth.json`, Codex environment variables, or the legacy Codex auth file as supported by `sub-core`.

`pi-service-tier` is not installed. Its provider-aware `/fast` support only exposes a footer widget through `pi-fancy-footer`, not through `pi-footer` or Pi's extension status API, so adding it here would not give an accurate status-line signal when switching between OpenAI and Anthropic.

## Local extensions

Home Manager deploys local Pi extensions under `~/.pi/agent/extensions/`.

`provider-router` lives at `~/.pi/agent/extensions/provider-router/`. It routes
Pi `subagent` tool calls to provider-specific models declared in assistant
`header.pi.yaml` files.

`pi-logo-filter` lives at `~/.pi/agent/extensions/pi-logo-filter/`. It imports
`pi-logo`'s header and animation helpers, but restricts random selection to
`logo-001` through `logo-009`.

`quota-status` lives at `~/.pi/agent/extensions/quota-status/`. It listens to
`sub-core` quota updates and publishes the compact quota segment consumed by
`pi-footer`.

Managed files:

- `~/.pi/agent/extensions/provider-router/index.ts`
- `~/.pi/agent/extensions/provider-router/agents.json`
- `~/.pi/agent/extensions/provider-router/README.md`
- `~/.pi/agent/extensions/provider-router/LICENSE`
- `~/.pi/agent/extensions/pi-logo-filter/index.ts`
- `~/.pi/agent/extensions/quota-status/index.ts`

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

The adapter reads the shared MCP config at `~/.config/mcp/mcp.json` automatically. That file is rendered by `../mcp` from `mcp/servers.nix`, so Pi uses the same canonical server definitions as Claude Code and other generic MCP clients.

`~/.pi/agent/mcp.json` is Pi-specific and is rendered through sops-nix because the full Context7 server entry includes an auth header. It carries conservative global adapter settings:

- `directTools = false`
- `disableProxyTool = false`
- `autoAuth = false`
- `sampling = false`
- `samplingAutoApprove = false`

That keeps the adapter's proxy tool enabled, disables direct tools by default, and prevents MCP servers from sampling through Pi. Project-level `.pi/mcp.json` files can override these settings deliberately.

Pi's adapter does not support a per-server `enabled` flag. Server presence in `mcpServers` means Pi can use it, and servers connect lazily when a tool call needs them.

Pi follows OpenCode's enabled-by-default MCP preference through `directTools`:

| Server | Pi default |
|--------|------------|
| `context7` | Direct tools promoted |
| `exa` | Direct tools promoted |
| `nixos` | Direct tools promoted |
| `cloudflare` | Present, proxy-only |
| `svelte` | Present, proxy-only |
| `playwright` | Present only on browser automation hosts, proxy-only when present |

The Pi-specific file emits full server entries, not partial overrides, because `pi-mcp-adapter` shallow-merges MCP config files by server name. A partial entry that only set `directTools` would replace the shared command, args, URL, or auth fields.

The Playwright MCP server remains gated by the shared MCP module. It appears only where browser automation is enabled, so server hosts such as `malak` do not receive it.

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

| Source | Pi destination | Mapping |
|--------|----------------|---------|
| `instructions/global.md` | `~/.pi/agent/AGENTS.md` | Global context file loaded by Pi |
| `agents/<name>/prompt.md` and `description.txt` | `~/.pi/agent/agents/<name>.md` | Pi subagent Markdown with YAML frontmatter |
| `agents/<name>/commands/<command>/prompt.md` | `~/.pi/agent/prompts/<name>-<command>.md` | Prompt template that asks Pi to call the matching subagent |
| `commands/<command>/prompt.md` | `~/.pi/agent/prompts/<command>.md` | Native Pi prompt template |
| `skills/<name>/` | `~/.pi/agent/skills/<name>/` | Symlinked Agent Skills directory |

Traya is the unnamed default prompt through `instructions/global.md`. She is not emitted as a named Pi subagent.

Pi agent frontmatter is sourced from `header.pi.yaml`. When the file is absent the agent inherits three defaults: `systemPromptMode: append`, `inheritProjectContext: false`, and `inheritSkills: true`. `name` and `description` are injected automatically from the directory name and `description.txt`. Per-agent values for `model`, `thinking`, `tools`, `defaultContext`, `maxSubagentDepth`, and other Pi-native fields go in `header.pi.yaml` alongside `header.claude.yaml` and `header.codex.toml`. Prompt templates use `header.pi.yaml` for `argument-hint` rather than reading the Claude header.

Pi subagent Markdown supports explicit `tools` allowlists through Pi-native
frontmatter when an individual agent needs a narrower tool surface.
