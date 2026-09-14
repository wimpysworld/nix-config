# OpenCode module

OpenCode with built-in LSP, IDE integration, and CUA-standard keybindings.

Home Manager enables OpenCode by default on non-server hosts. Default servers do not install OpenCode or `opencode-fenced` unless another module enables `programs.opencode`.

Agents, commands, skills, and global instructions are managed separately in the **[assistants module](../assistants/README.md)** and composed for OpenCode, Claude Code, Codex, and Pi Agent by the assistants mixin.

## Package selection

`inputs.llm-agents.packages.opencode` from the `llm-agents` flake input (pre-built binary, avoids upstream source build issues).

## API keys

On personal physical computers, the wrapper reads the managed `ANTHROPIC_API_KEY` at invocation. It exports the key only for the OpenCode launch. Hosts tagged `cg` do not receive the managed key.

Plain `opencode` and `opencode-fenced` use the same runtime loader. The fenced wrapper reads the key before it enters Fence. Fence receives the key through the inherited environment. The key is absent from the Nix store, Home Manager session variables, and Fence command arguments.

## Contents

- **LSP configuration** - Built-in language server support; only Semgrep is configured explicitly for security diagnostics
- **[MCP servers](../mcp/README.md)** - Shared MCP servers, with browser automation included only on systems that enable both Chromium and Firefox; delivered to OpenCode via `settings.json`
- **[Fence](../fence)** - `opencode-fenced` runs OpenCode under the shared Fence permission and isolation policy.
- **IDE integration** - VSCode extension, Zed editor as external agent
- **TUI configuration** - Catppuccin theme, CUA-standard keybindings

## Agent Tripwire

OpenCode receives the portable `communication-rules` skill from the assistants module. Global context and generated agents load it by name. Reminders, block messages, and correction requests use the complete skill body without frontmatter.

Tripwire uses a global OpenCode plugin. The native `tool.execute.before` surface gates outgoing writes, edits, patches, Bash prose side effects, and external post bodies. If an outgoing side effect cannot be inspected, the plugin fails closed.

OpenCode v1 cannot hard-block final or subagent prose before display. The accepted Tripwire surface is post-display detection with a correction request, so the docs and plugin must not claim a pre-display hard block for those messages.

There is no OpenCode command, flag, environment variable, allow rule, or prompt escape that bypasses Tripwire. Operator recovery is still available through normal config disablement, such as `disableAllHooks`, or by rebuilding without the Agent Tripwire mixin.

## Provider router prototype

Home Manager installs `plugins/provider-router.ts` when OpenCode is enabled, without a version restriction.

The shared agent header owns the routes. Garfield alone declares:

```toml
[routing.opencode.providers.openai]
model = "gpt-5.6-terra"

[routing.opencode.providers.anthropic]
model = "claude-sonnet-5"
```

`assistants/metadata.nix` validates these tables. `compose.nix` extracts the map, and the OpenCode module supplies it to `provider-router/index.mjs`. Provider routes cannot coexist with native agent model or effort pins. Commands and skills cannot declare provider routes. No provider-route fields enter native headers.

The plugin changes only `chat.message` output for a direct child of a root session. It matches one running native `task` part by `state.metadata.sessionId`. The containing assistant message supplies the provider, not the latest parent message or the session model. Simultaneous siblings remain independent. Missing or ambiguous matches, root sessions, nested sessions, and missing routes retain native behaviour. Google has no route and no preview-model substitution.

An unavailable exact provider or model rejects the prompt. The plugin never searches another provider. It leaves native task arguments, permissions, cancellation, and model variants unchanged. Per-call overrides and thinking controls are outside this prototype.

The plugin saves its route in supported text-part metadata, alongside the routed user message. Resume restores that saved model, even after the parent changes provider. Existing children without route metadata retain native behaviour. Invalid saved metadata rejects the prompt. Keep child and originating parent history together. Removing or importing partial history can prevent safe restoration.

An in-process guard rejects overlapping child hooks and further prompts while the routed task remains active. Saved invocation metadata also rejects a repeated active task after restart. Multiple running task matches with no established route remain ambiguous and use native behaviour.

### Version evidence and tests

OpenCode v1.18.30 is the tested and source-reviewed version, not a supported-version limit. The source review covers:

- [Public `chat.message` hook](https://github.com/anomalyco/opencode/blob/v1.18.30/packages/plugin/src/index.ts#L234-L243).
- [Task metadata before the child prompt](https://github.com/anomalyco/opencode/blob/v1.18.30/packages/opencode/src/tool/task.ts#L150-L256).
- [Live message persistence and inference model selection](https://github.com/anomalyco/opencode/blob/v1.18.30/packages/opencode/src/session/prompt.ts#L999-L1141).
- [SDK session, message, and provider types](https://github.com/anomalyco/opencode/blob/v1.18.30/packages/sdk/js/src/gen/types.gen.ts).
- [Supported text-part metadata](https://github.com/anomalyco/opencode/blob/v1.18.30/packages/schema/src/v1/session.ts#L102-L116).

Run the offline checks from the repository root:

```sh
node --test home-manager/_mixins/agentic/opencode/provider-router/index.test.mjs
python -m unittest discover -s home-manager/_mixins/agentic/assistants/tests
just eval
```

Router tests use SDK fixtures and a fresh process with serialised history. They make no inference requests. They do not replace a live OpenCode integration test.

## LSP

OpenCode includes built-in LSP support - no per-language server configuration required. The only explicit LSP entry is Semgrep, added for security diagnostics across all supported file types (50+ extensions covering R, Bash, C/C++, Clojure, Dart, Elixir, Go, Java, JavaScript/TypeScript, Julia, Kotlin, Lua, Nix, PHP, Python, Ruby, Rust, Scala, Swift, Terraform, and more).

## Custom commands

The built-in `/init` command is overridden to use Rosey's `create-agents-md` prompt, routing project initialisation through the orchestrator agent.

## Shell alias

OpenCode uses the unnamed global prompt from `instructions/global.md` for default orchestration. Traya is not exposed as a named OpenCode agent.

This module provides `opencode-fenced` for the Fence-isolated entry point. It
runs the normal `opencode` TUI under Fence with
`OPENCODE_PERMISSION='{"*":"allow"}'`, so OpenCode loads the same configuration
as plain `opencode` while Fence provides the managed filesystem, network, and
command policy.

## IDE integration

| Editor     | Integration                                                                                                                 |
| ---------- | --------------------------------------------------------------------------------------------------------------------------- |
| **VSCode** | `sst-dev.opencode` extension                                                                                                |
| **Zed**    | `opencode` extension + external agent thread via `opencode acp` (Agent Communication Protocol). Keybind: `Ctrl+Alt+Shift+P` |

Zed also registers Claude Code as a separate external agent thread at `Ctrl+Alt+Shift+C`.

## TUI configuration

- **Theme:** Catppuccin
- **Diff style:** Stacked
- **Scroll acceleration:** Enabled

### Keybindings

CUA-standard (Common User Access) keybindings matching Windows/Linux text editor conventions.

| Action            | Binding                                          |
| ----------------- | ------------------------------------------------ |
| **Navigation**    | Arrow keys, Home/End, Ctrl+Home/End              |
| **Word movement** | Ctrl+Left/Right                                  |
| **Selection**     | Shift+Arrows, Shift+Home/End                     |
| **Select all**    | Ctrl+A (selects to buffer start)                 |
| **Clipboard**     | Ctrl+V paste, Ctrl+Insert copy, Shift+Delete cut |
| **Undo/Redo**     | Ctrl+Z / Ctrl+Shift+Z                            |
| **Submit**        | Enter                                            |
| **Newline**       | Shift+Enter, Ctrl+Enter                          |
| **Chat scroll**   | PgUp/PgDn, Shift+PgUp/PgDn (jump to first/last)  |
| **History**       | Ctrl+Up/Down                                     |
| **Quit**          | Ctrl+Q                                           |
| **Interrupt**     | Escape                                           |
