# OpenCode module

OpenCode with built-in LSP, IDE integration, and CUA-standard keybindings.

Agents, commands, skills, and global instructions are managed separately in the **[assistants module](../assistants/README.md)** and composed for OpenCode, Claude Code, and Codex by `assistants/compose.nix`.

## Package selection

`inputs.llm-agents.packages.opencode` from the `llm-agents` flake input (pre-built binary, avoids upstream source build issues).

## Contents

- **LSP configuration** - Built-in language server support; only Semgrep is configured explicitly for security diagnostics
- **[MCP servers](../mcp/README.md)** - Shared MCP servers, with browser automation included only on systems that enable both Chromium and Firefox; delivered to OpenCode via `settings.json`
- **[Fence](../fence)** - `opencode-fenced` runs OpenCode under the shared Fence permission and isolation policy.
- **IDE integration** - VSCode extension, Zed editor as external agent
- **TUI configuration** - Catppuccin theme, CUA-standard keybindings

## Agent Tripwire

OpenCode receives the shared Communication Rules fragment from the assistants module. The fragment is generated once by Nix and reused by OpenCode global context, generated agents, reminders, block messages, and correction requests.

Tripwire uses a global OpenCode plugin. The native `tool.execute.before` surface gates outgoing writes, edits, patches, Bash prose side effects, and external post bodies. If an outgoing side effect cannot be inspected, the plugin fails closed.

OpenCode v1 cannot hard-block final or subagent prose before display. The accepted Tripwire surface is post-display detection with a correction request, so the docs and plugin must not claim a pre-display hard block for those messages.

There is no OpenCode command, flag, environment variable, allow rule, or prompt escape that bypasses Tripwire. Operator recovery is still available through normal config disablement, such as `disableAllHooks`, or by rebuilding without the Agent Tripwire mixin.

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
