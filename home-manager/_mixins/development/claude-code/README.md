# Claude Code module

Claude Code with LSP integration, MCP servers, permission policy, and a ccstatusline status bar.

## Package selection

The package source varies by platform:

- **Linux** - `llm-agents.packages.claude-code` from the `llm-agents` flake input
- **macOS** - `pkgs.unstable.claude-code`
- **Fallback** - `pkgs.claude-code`

## Contents

- **[LSP configuration](LSP.md)** - Language server integration via the plugin system; 14 servers across 10 language modules, contributed by each language module via the `claude-code.lspServers` option
- **MCP servers** - Model Context Protocol servers configured via `~/.config/claude/claude_desktop_config.json`
- **Permission policy** - Tool allow/deny rules applied at startup
- **ccstatusline** - Status bar integration reporting active session state
