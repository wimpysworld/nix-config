# Pi Agent module

Installs [Pi Agent](https://github.com/badlogic/pi-mono), the `pi` coding-agent CLI, for developer-tagged Home Manager users.

The upstream package comes from `inputs.llm-agents.packages.${system}.pi`, matching the other coding-agent packages sourced from `numtide/llm-agents.nix`.

## Behaviour

- Adds a `pi` wrapper to `home.packages`
- Adds `pi-fenced`, which runs the standard `pi` wrapper under the shared [Fence](../fence) permission and isolation policy
- Gates installation with `noughtyLib.userHasTag "developer"`
- Exports `ANTHROPIC_API_KEY` from the sops-nix runtime secret path only on personal physical computers
- Exports `GEMINI_API_KEY` (and `GOOGLE_GENERATIVE_AI_API_KEY`) and `BASETEN_API_KEY` from sops-nix runtime secret paths when present
- Exports `OPENCODE_ZEN_API_KEY` from its sops-nix runtime secret path on hosts without the `cg` tag
- Exports `ANTHROPIC_OAUTH_TOKEN` from Claude Code's local OAuth credentials when available, so quota extensions can query Anthropic plan windows
- Adds a `pi-npm` wrapper backed by Nixpkgs `nodejs`, with npm's global prefix redirected to `~/.pi/agent/npm-global` and routine npm advisory output disabled
- Owns Pi config and resource files through Home Manager:
  - `~/.pi/agent/settings.json`
  - `~/.pi/agent/models.json` on hosts without the `cg` tag
  - `~/.pi/agent/mcp.json`
  - `~/.pi/agent/extensions/pi-footer.json`
  - `~/.pi/agent/pi-sub-core-settings.json`
  - `~/.pi/agent/subagents.json`
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
    "npm:pi-mcp-adapter@2.37.0",
    "npm:@tintinweb/pi-subagents@0.19.0",
    "npm:pi-lens@4.2.1",
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
    "npm:@heyhuynhgiabuu/pi-pretty@0.6.29",
    "npm:@juicesharp/rpiv-ask-user-question@2.11.0",
    "npm:@juicesharp/rpiv-btw@2.11.0",
    "npm:@tintinweb/pi-tasks@0.9.0"
  ]
}
```

Versioned Pi package specs are pinned and skipped by `pi update`. These packages are user-level JavaScript extensions installed by Pi's npm integration under the user-owned npm prefix. `typescript` supplies the compiler API that `pi-lens` imports at runtime but omits from its runtime dependencies. Its Pi resources are disabled because it is a runtime dependency, not an extension.

`pi-lens` 4.2.1 declares an optional `@earendil-works/pi-tui` peer range of `^0.84.1 || ^0.85.0`, which excludes the selected Pi 0.87.1. Full runtime compatibility remains unverified. Since 4.1.6, use `lens_diagnostics` with `source: "lsp"` instead of `lsp_diagnostics`, and `ast_grep_search` with `dump: true` instead of `ast_grep_dump`.

`pi-cc-header` loads from its npm package with `ccHeader.readOnlyConfig` set in the Home Manager-owned `settings.json`. That upstream read-only mode (added in 1.1.1 for declarative setups) stops the extension writing `settings.json`, so header commands such as `/htg` apply for the current session only. It replaces the local writable-state patch that earlier releases needed.

[`pi-pretty`](https://github.com/heyhuynhgiabuu/pi-pretty) re-renders built-in tool output: syntax-highlighted `read` previews, coloured `bash` exit summaries, Nerd Font `ls` icons, and FFF frecency-backed `find`/`grep`. Home Manager owns `~/.pi/agent/pi-pretty.json`, which selects the Catppuccin Shiki theme, keeps Nerd Font icons on, and opts in the `ls` renderer. `pi-fff` must not be installed alongside it because both claim the same built-in tool names. FFF index data lives under `~/.pi/agent/pi-pretty/fff/`.

The `juicesharp/rpiv-mono` extensions add native Pi behaviour:

- `rpiv-ask-user-question` gives the model a structured questionnaire with typed options
- `rpiv-btw` performs an explicit side model call using current conversation context

[`pi-tasks`](https://github.com/tintinweb/pi-tasks) adds Claude Code-style task tracking: `TaskCreate`, `TaskList`, `TaskGet`, `TaskUpdate`, `TaskOutput`, `TaskStop`, and `TaskExecute` tools, a persistent widget above the editor, reminder injection, dependency tracking, and file-backed shared task lists. `TaskExecute` can run tasks with an `agentType` as subagents through the pinned `pi-subagents` package. The `/tasks` command configures widget display, saved as project overrides in `.pi/tasks-config.json`, which stays user-owned.

`@juicesharp/rpiv-args` and `@juicesharp/rpiv-i18n` are not installed. Pi natively substitutes `$1`/`$@`/`$ARGUMENTS` inside prompt templates and appends trailing arguments as a follow-up `User:` message after skill bodies. `rpiv-args` extended placeholder substitution into skill bodies as well, which silently rewrites incidental `$1` and `$NNNN` matches inside reference content (for example SQL placeholder syntax and currency strings in the security skills); the Pi-native split is preferred.

## Status line

[`pi-footer`](https://github.com/wobondar/pi-footer) replaces the older `pi-bar` footer. Home Manager owns `~/.pi/agent/extensions/pi-footer.json` and renders one compact line:

```text
 model thinking · Fast state · dir · quota windows · context window · Context N% used
```

Quota data comes from [`@marckrenn/pi-sub-core`](https://github.com/marckrenn/pi-sub). `sub-core` auto-detects the active provider from the current model. The local `quota-status` extension publishes the first two quota windows through Pi's extension status API, which `pi-footer` displays when data is available. Anthropic can provide 5h and weekly windows. OpenAI Codex provides its primary and secondary windows.

On personal physical computers the API key is the only Anthropic credential, so no plan quota exists. The footer shows `pi-footer`'s `cost` widget in the quota slot instead, which is the estimated session spend in USD from Pi's own usage metrics.

The footer uses the same Catppuccin colour roles as `ccstatusline`: model and thinking yellow, fast state mauve, current directory green, quotas red, and context peach. A white Pi glyph (`nf-fae-pi`) leads the line so the Pi footer is distinguishable from the Codex status line at a glance.

`quota-status` uses stable window labels where possible and displays remaining quota, not used quota, so Anthropic usually appears as:

```text
 claude-opus-5 high · Fast off · project · 5h 93% · weekly 96% · 1.0M window · Context 3.1% used
```

Home Manager also owns `~/.pi/agent/pi-sub-core-settings.json` to refresh quota data every five seconds and on turn start. `sub-core` renders cached state first, so the quota segment can appear a few seconds after the footer itself. If Anthropic returns only the 5h window, `quota-status` mirrors the Claude Code statusline helper by treating the missing weekly bucket as 100% remaining. Other providers show only the usable windows they return. `quota-status` keeps the last valid value for the active provider when `sub-core` emits a transient empty update.

Anthropic quota data requires an OAuth token, not the `ANTHROPIC_API_KEY` used for model calls. The `pi` wrapper reads `~/.claude/.credentials.json` or `$CLAUDE_CONFIG_DIR/.credentials.json` and exports `ANTHROPIC_OAUTH_TOKEN` when the Claude Code login token has the `user:profile` scope. Without that local login, the Anthropic quota segment stays hidden. OpenAI Codex quota data comes from Pi's `auth.json`, Codex environment variables, or the legacy Codex auth file as supported by `sub-core`.

The local `service-tier-status` extension owns `/fast on`, `/fast off`, and `/fast status`. Bare `/fast` shows status. Repeated `on` or `off` commands are safe. Invalid arguments do not change the selection. Changes wait for idle so request headers and bodies agree.

Fast starts off in every session, including children, resume, fork, and `/reload`. Model or provider changes reset Fast off. The selection stays in memory only. The extension does not read or change legacy `~/.pi/agent/service-tier.json`, model selection, or thinking levels. `pi-service-tier` is no longer installed through this configuration. Do not load it separately because its request hooks and commands conflict with this policy.

| Direct provider | Off request | On request |
| --- | --- | --- |
| OpenAI Responses | `service_tier: "default"` | `service_tier: "priority"` |
| OpenAI Codex | Omit `service_tier` | `service_tier: "priority"` |
| Anthropic | Remove `speed` and the exact Fast beta token, set `service_tier: "standard_only"` | Add `speed: "fast"` and `fast-mode-2026-02-01`, retain `standard_only` |

Fast requires a registered model and an exact verified ID. OpenAI supports `gpt-6-astra`, `gpt-5.6-sol`, `gpt-5.6-terra`, and `gpt-5.6-luna`. Anthropic supports `claude-opus-5` and `claude-opus-4-8`. Pi's catalogue has no speed capability field, so other IDs stay unavailable until verified. Custom endpoints and other providers stay unavailable without a claim that standard speed is enforced.

The footer shows `Fast on` for a requested priority tier or Fast mode, and `Fast off` otherwise. It reports the session selection, not the server response or account entitlement. Unsupported models show `Fast off`. `/fast` notifications retain availability details. Codex tier omission follows its native off behaviour, not a verified server guarantee. `auto`, `flex`, and Anthropic service priority are not Fast speed. See the [OpenAI Fast mode contract](https://developers.openai.com/api/docs/guides/fast-mode) and [Anthropic Fast mode contract](https://platform.claude.com/docs/en/build-with-claude/fast-mode).

## Local extensions

Home Manager deploys local Pi extensions under `~/.pi/agent/extensions/`.

`provider-router` lives at `~/.pi/agent/extensions/provider-router/`. It routes
new named children from Pi `Agent` and `SubagentWorkflow` calls through agent
`header.toml` defaults under `[routing.pi.<inference-provider>]`.
The provider must match the active provider exactly. Missing routes use native fallback.
Explicit launch-time child model and thinking overrides remain supported.
Commands and skills never change the caller's model or thinking.
`routeInvocation` and `provider-router:invoke` remain no-ops for display compatibility.

`quota-status` lives at `~/.pi/agent/extensions/quota-status/`. It listens to
`sub-core` quota updates and publishes the compact quota segment consumed by
`pi-footer`.

`service-tier-status` lives at `~/.pi/agent/extensions/service-tier-status/`.
It applies the session-local request policy and publishes requested speed through
`noughty-service-tier:status`, which `pi-footer` consumes. Run its offline checks with Node.js 24 or later:

```sh
node --test home-manager/_mixins/agentic/pi/extensions/service-tier-status/index.test.mjs
```

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
displayed `Agent`, `get_subagent_result`, and `SubagentWorkflow` tool results.

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
- `~/.pi/agent/extensions/provider-router/thinking.json`
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

`secrets/ai.yaml` provides `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`, `BASETEN_API_KEY`, and `OPENCODE_ZEN_API_KEY`.

On hosts without the `cg` tag, Home Manager owns `~/.pi/agent/models.json`. Its `providers.opencode.apiKey` value is `$OPENCODE_ZEN_API_KEY`. Pi resolves that reference from the wrapper's environment and keeps its built-in models. See Pi's [provider overrides and value resolution](https://github.com/badlogic/pi-mono/blob/v0.85.1/packages/coding-agent/docs/models.md). The configuration contains no secret value.

On personal physical computers, the `pi` wrapper reads `config.sops.secrets.ANTHROPIC_API_KEY.path` at runtime and exports the key only for the Pi process. On other hosts, the evaluated wrapper contains neither that secret path nor the `ANTHROPIC_API_KEY` export. When Claude Code OAuth credentials exist locally, every host still exports `ANTHROPIC_OAUTH_TOKEN` for Pi's quota extensions. The managed `settings.json` and all managed Pi resource files contain no literal secret values.

This module does not manage `~/.pi/agent/auth.json`. Pi can still create that file through `/login` for subscription providers or manually entered API keys.

## Fenced mode

Use `pi-fenced` for the Fence-isolated entry point. It runs the same Home
Manager-managed `pi` wrapper as plain `pi`, so both entry points use the same
host gate and runtime secret read. Fence receives no secret value in its
arguments. Fence still provides the managed filesystem, network, and command
policy.

On Linux, each `pi-fenced` launch outside an existing Fence sandbox mounts a
private, mode-0700 tmpfs at `$HOME/.pi/agent/pi-pretty/fff` before Fence starts.
Fence exposes that mount as writable. Descendants share it, but separate
launches do not share FFF databases. This prevents LMDB lock collisions between
processes with the same PID in separate PID namespaces. FFF indexes and frecency
history last only for that launch and its descendants. The existing host
database stays unchanged beneath the mount. `HOME` and other shared Pi state
stay unchanged. macOS behaviour is unchanged, and servers do not install
`pi-fenced`.

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

[Tintinweb pi-subagents](https://github.com/tintinweb/pi-subagents) is pinned to `npm:@tintinweb/pi-subagents@0.19.0`.
Home Manager writes its settings to `~/.pi/agent/subagents.json`.
The former package, configuration output, and `subagents.disableBuiltins` setting are no longer configured.
Historical logs and sessions remain untouched.

| Setting | Value | Effect |
| --- | --- | --- |
| `backgroundByDefault` | `true` | Detached `Agent` calls notify the parent on completion. |
| `maxConcurrent`, `maxConcurrentForeground` | `12` each | Independent background and foreground pools, not a combined cap. |
| `maxSubagentDepth` | `1` | Only the coordinator launches specialists. |
| `defaultMaxTurns`, `graceTurns` | `50`, `5` | Bounded turns, not a wall-clock deadline. |
| `disableDefaultAgents`, `strictAgentFiles` | `true` | Use explicit custom agents and reject malformed headers. |
| `fallbackSubagent` | `"none"` | Do not substitute a default agent. |
| `defaultJoinMode` | `"async"` | Use native completion delivery. |
| `rememberAgents`, `outputTranscript` | `true` | Preserve sessions and transcripts for inspection and continuation. |
| `workflowsEnabled` | `true` | Enable routed scripted workflows. |
| `agentMentions`, `schedulingEnabled` | `"off"`, `false` | Avoid launch paths that bypass routing. |
| `worktreeIsolation` | `false` | Avoid upstream cleanup that can lose uncommitted work. |

Use `Agent` with `subagent_type`, `description`, and `prompt`. Set `inherit_context: false` for fresh context.
`run_in_background: false` requests a foreground child. Both modes retain extensions and skills.
Use `get_subagent_result` for completed output, `steer_subagent` for active guidance, and `Agent` with `resume` for continuation.
Children run as SDK sessions inside Pi. They do not continue execution after the parent process exits.

Use `SubagentWorkflow` with inline source, `scriptPath`, or a saved `name`.
Scripts use `agent(prompt, { agentType })`, `parallel`, and `pipeline`.
The router limits each workflow to twelve active calls. The native runtime retains its 1000-call limit per workflow.
Failed or skipped required results still fail the workflow.
Each workflow has a separate pool, independent of both direct pools, so twelve is not a global aggregate cap.
Shared instructions require the coordinator to keep at most twelve workers active across all delegation tools and workflows combined.
This aggregate rule is guidance, not a shared scheduler.
Native CPU-based capacity can lower workflow concurrency. Foreground resumes can exceed their pool limit.
Nested `workflow()` calls are rejected because their source bypasses routing. Launch saved workflows through the tool instead.
Use separate sessions in separate checkouts for concurrent writers. Isolation requests fail rather than silently using the shared checkout.

After activation, close the old Pi session and start a fresh session. Do not load both subagent extensions together.

## Assistant mapping

Source content comes from `home-manager/_mixins/agentic/assistants`. Rendering for Pi lives in `home-manager/_mixins/agentic/assistants/default.nix`; this module consumes the generated Home Manager file entries.

| Source                                          | Pi destination                     | Mapping                                                                                                                                                                                                                                                                                                            |
| ----------------------------------------------- | ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `instructions/global.md`                        | `~/.pi/agent/AGENTS.md`            | Global context file loaded by Pi                                                                                                                                                                                                                                                                                   |
| `agents/<name>/prompt.md` and `header.toml` | `~/.pi/agent/agents/<name>.md`     | Pi subagent Markdown with YAML frontmatter                                                                                                                                                                                                                                                                         |
| `commands/<command>/command.toml` plus `command.md` or `command.sops` | `~/.pi/agent/prompts/<command>.md` | Prompt template. Explicit `compose.agent` selects the worker unless `compose.caller-context` or provider inline controls override dispatch. |
| `skills/<name>/`                                | `~/.pi/agent/skills/<name>/`       | Symlinked Agent Skills directory                                                                                                                                                                                                                                                                                   |

Traya is the unnamed default prompt through `instructions/global.md`. She is not emitted as a named Pi subagent.

Activation preserves unmanaged agents, including `~/.pi/agent/agents/traya.md`. Public resource links remain Home Manager-owned. Secret resource links use the shared [activation ownership and cleanup](../assistants/README.md#activation-ownership-and-cleanup) helper.

Pi agent frontmatter comes from `header.toml`. Generated defaults are `prompt_mode: replace`, `extensions: true`, `skills: true`, and `isolated: false`.
The composer preserves specialist bodies and adds the leaf contract, shared safety rules, and house style only for Pi.
Children read applicable project instructions themselves instead of copying the parent's system prompt.
Names derive from directories, and descriptions come from `[common] description`.

Native non-model fields, such as `tools`, `max_turns`, `persist_session`, and `run_in_background`, belong under `[pi]`.
Omit `inherit_context` so the caller can select fresh or inherited context.
Agent model and thinking defaults belong under `[routing.pi.<inference-provider>]`.
Generated native agent headers leave model and thinking unset so routed launch arguments take effect.
Separately installed native agent pins can take precedence over `Agent` launch arguments.
Non-empty Pi command and skill routing fails evaluation. Custom child `command` and `directSkill` routing fields are no longer supported.
Prompt templates receive `argument-hint` from `[common]` or `[pi]`. Missing tables mean no overrides, not disabled output.

Pi subagent Markdown supports explicit `tools` allowlists through Pi-native
frontmatter when an individual agent needs a narrower tool surface.
