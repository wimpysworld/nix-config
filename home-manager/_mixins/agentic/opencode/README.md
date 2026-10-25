# OpenCode V2 module

Home Manager installs OpenCode V2 on non-server hosts by default. Servers need an explicit `programs.opencode.enable` setting.

The [assistants module](../assistants/README.md) supplies shared agents, commands, skills, and global instructions. This module owns the launcher, native settings, terminal settings, and local plugins.

## Package and configuration

The module selects `inputs.llm-agents.packages.${system}.opencode2`. The current pin is `2.1.2`. The public command remains `opencode`, including for editors and Herdr. Nix owns updates, so native automatic updates are disabled.

Server settings use native V2 fields in `opencode.json`. Terminal settings use `cli.json`, with native keybinding names and the built-in Catppuccin themes. The V1 Catppuccin generator is disabled. Linux hosts also receive the matching Herdr terminal plugin.

No local provider or model allowlist filters the catalogue. The default model is `opencode-go/glm-5.3-flash`. OpenCode Go and the pay-as-you-go `opencode` provider remain separate providers.

The six OpenAI model limit overrides remain in `default.nix`. Automatic compaction uses V2's resolved input limit and default reserve. The old fixed 345,600-token trigger does not apply.

Session sharing and the built-in `webfetch` and `websearch` tools are disabled. Web access uses the shared [MCP servers](../mcp/README.md). Plain launches ask before access to external directories.

## Credentials

The runtime wrapper reads managed credentials at invocation. Missing credential files do not prevent startup.

| Credential | Delivery |
| --- | --- |
| `GEMINI_API_KEY` | Exported under its own name and `GOOGLE_GENERATIVE_AI_API_KEY`. |
| `ANTHROPIC_API_KEY` | Exported on personal physical computers. |
| `OPENCODE_API_KEY` | Exported on hosts without the `cg` tag, for both OpenCode gateways. |

`OPENCODE_API_KEY` is the canonical gateway name. The wrapper does not export the retired `OPENCODE_ZEN_API_KEY` alias.

The fenced wrapper reads credentials before it enters Fence. Credentials pass through the process environment, not command arguments or Home Manager session variables. Secret values stay outside the Nix store.

## Private servers and Fence

The launcher adds `--standalone` to supported server-backed commands. For `auth` and `session`, the flag follows the selected leaf command. ACP starts its own private server.

Interactive root and `mini` launches also receive `--continue`, unless the caller supplies a session or continuation choice. Management commands do not receive automatic resume flags. Help and version requests pass through unchanged.

Outside Fence, an explicit `--server` selects an external server. That server owns credentials, configuration, and tool execution. The local wrapper cannot enforce its trusted-directory policy on an external server.

`opencode-fenced` runs the client and private server inside Fence. It rejects external server selection and commands without a private-server contract, including `service`, `serve`, `pair`, `mcp`, `plugin`, and `debug`.

Inside Fence, the provider-router plugin changes permission results from `ask` to `allow`. Explicit denies remain denied, including the web-tool and shared MCP denies. The wrapper does not use the unsupported V1 `OPENCODE_PERMISSION` override.

The launcher disables model-catalogue downloads. It disables project configuration outside `~/Chainguard`, `~/Development`, `~/Volatile`, and `~/Zero`. Directory checks use canonical paths, including an explicit root directory and the target of `session import --directory`.

## Agent Tripwire

Home Manager links each plugin directory to a store directory with a regular `index.ts` file. V2 rejects entrypoint symlinks that escape their plugin directory.

The directory plugin `plugins/communication-rules/index.ts` uses V2 session hooks to inject the Communication Rules. Its `execute.before` tool hook checks outgoing prose side effects through the shared Python scanner. Scanner failures block tool execution.

Final-message checks run after display. A detected violation adds a synthetic notice, without an automatic model turn. These checks do not provide a pre-display hard block for final or subagent prose.

Remove the Agent Tripwire configuration through a reviewed rebuild for operator recovery. Prompts do not provide a Tripwire bypass.

## Provider routing

`plugins/provider-router/index.ts` loads the route maps from shared agent headers. Routes remain separate from native agent model pins. Commands and skills cannot declare provider routes.

The V2 prompt hook routes direct children of root sessions. It finds the running `subagent` call that names the child. The containing assistant message supplies the provider, so concurrent siblings remain independent.

Missing routes retain native behaviour. Explicit native per-call model choices also retain native behaviour. An unavailable exact model or variant rejects the prompt without a provider fallback.

V2 plugin storage preserves each selected route across compaction and restart. A new invocation can restore the saved route after the parent changes provider. Invalid saved routes and repeated active invocations fail closed.

Existing children without a V2 saved route retain native behaviour. V1 text-part route metadata does not migrate into this plugin's storage. Keep the child history, parent history, and plugin storage together.

## Editors and terminal settings

Zed continues to use `opencode acp`. V2's HTTP API is incompatible with V1 clients, so HTTP-based editor integrations need separate validation.

V2 accepts LSP configuration but does not run language servers or diagnostics. The existing Semgrep LSP setting does not provide a security check in V2. Use the repository's lint and test commands.

The terminal uses unified diffs, accelerated scrolling, and Common User Access (CUA) navigation.

| Action | Binding |
| --- | --- |
| Navigation | Arrows, Home/End, Ctrl+Home/End |
| Word movement | Ctrl+Left/Right |
| Selection | Shift+Arrows, Shift+Home/End |
| Select to buffer start | Ctrl+A |
| Paste | Ctrl+V, Shift+Insert, Ctrl+Shift+V |
| Undo/redo | Ctrl+Z / Ctrl+Shift+Z |
| Submit | Enter |
| Newline | Shift+Enter, Ctrl+Enter |
| Chat scroll | Page Up/Down, Shift+Page Up/Down |
| History | Ctrl+Up/Down |
| Quit | Ctrl+D |
| Interrupt | Escape |

The `/init` command uses Rosey's `create-agents-md` prompt. Default orchestration uses the global instructions, not a named Traya agent.

## Validation and first launch

The launcher build runs the router, Tripwire, and launcher suites in an isolated HOME and XDG environment. The fixtures do not make inference requests.

The build also starts isolated V2 servers against the generated Home Manager plugin sources. It checks discovery, rejects the old file-link layout, and verifies fenced approval changes without weakening explicit denies. These build-only tests use no credentials or MCP servers.

Run the offline suites from the repository root:

```sh
bun test home-manager/_mixins/agentic/opencode/provider-router/index.test.mjs \
  home-manager/_mixins/agentic/opencode/plugins/communication-rules.test.ts \
  home-manager/_mixins/agentic/opencode/launcher.test.ts
```

Before the first production V2 launch, stop OpenCode writers and make a consistent private backup of configuration, data, and state. Include any `OPENCODE_DB` database, SQLite sidecars, and the V1 Home Manager generation reference. V1 and V2 share default state paths. `--standalone` does not isolate the database.

Rehearse migration only on a separate copy with isolated HOME and XDG paths. V2 migration resets session permissions and revert pointers, and can omit malformed legacy records. It does not provide two-way session history synchronisation.

For rollback, stop V2 writers and restore the V1 generation with the untouched pre-migration state. Preserve V2-only work separately. Activation and production migration require explicit operator approval.
