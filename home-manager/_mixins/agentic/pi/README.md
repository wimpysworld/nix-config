# Pi Agent module

Installs [Pi Agent](https://github.com/badlogic/pi-mono), the `pi` coding-agent CLI, for developer-tagged Home Manager users.

The upstream package comes from `inputs.llm-agents.packages.${system}.pi`, matching the other coding-agent packages sourced from `numtide/llm-agents.nix`.

## Behaviour

- Adds a `pi` wrapper to `home.packages`
- Gates installation with `noughtyLib.userHasTag "developer"`
- Exports `ANTHROPIC_API_KEY` from the sops-nix runtime secret path before execing the Nix-provided Pi binary
- Adds a `pi-npm` wrapper backed by Nixpkgs `nodejs`, with npm's global prefix redirected to `~/.pi/agent/npm-global` and routine npm advisory output disabled
- Owns Pi config and resource files through Home Manager:
  - `~/.pi/agent/settings.json`
  - `~/.pi/agent/mcp.json`
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
    "npm:pi-mcp-adapter@2.5.4",
    "npm:pi-subagents@0.24.0",
    "npm:@juicesharp/rpiv-args@1.1.5",
    "npm:@juicesharp/rpiv-btw@1.1.5",
    "npm:@juicesharp/rpiv-todo@1.1.5"
  ]
}
```

Versioned Pi package specs are pinned and skipped by `pi update`. These packages are user-level JavaScript extensions installed by Pi's npm integration under the user-owned npm prefix.

The `juicesharp/rpiv-mono` extensions add native Pi behaviour:

- `rpiv-args` adds skill argument placeholders
- `rpiv-btw` performs an explicit side model call using current conversation context
- `rpiv-todo` adds a model-visible todo tool and `/todos` UI

`@juicesharp/rpiv-i18n` is not installed.

## Theme

Pi supports JSON themes loaded from `~/.pi/agent/themes/*.json`, package theme directories, or the `themes` setting.

This module writes `~/.pi/agent/themes/catppuccin-mocha.json` from the repository's `catppuccinPalette` and sets Pi's default theme to `catppuccin-mocha`. No third-party theme package is installed.

## Authentication

`secrets/ai.yaml` provides `ANTHROPIC_API_KEY`.

The `pi` wrapper reads `config.sops.secrets.ANTHROPIC_API_KEY.path` at runtime and exports the key only for the Pi process. The managed `settings.json` and all managed Pi resource files contain no literal secret values.

This module does not manage `~/.pi/agent/auth.json`. Pi can still create that file through `/login` for subscription providers or manually entered API keys.

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

`maxSubagentDepth = 1` allows explicit direct subagent use and blocks nested subagent chains by default. Each generated assistant agent also sets `maxSubagentDepth: 0`, so child sessions cannot delegate further.

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

Traya is written during Home Manager activation rather than through `home.file`, because her prompt appends the sops-backed bond text outside the Nix store. Other agents and prompts contain no secrets and are rendered declaratively.

Pi agent frontmatter uses `name`, `description`, `systemPromptMode: append`, `inheritProjectContext: true`, `inheritSkills: true`, and `maxSubagentDepth: 0`. Prompt templates carry `description` and reuse Claude's `argument-hint` field where present, because Pi supports the same prompt-template field.

OpenCode-specific permission headers are not mapped. Pi subagent Markdown supports tool allowlists, but OpenCode's allow/deny permission policy does not translate cleanly into Pi's explicit `tools` allowlist.
