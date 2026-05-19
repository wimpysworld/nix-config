# Claude Code module

Claude Code with LSP integration, MCP servers, default Claude permissions, and a ccstatusline status bar.

Agents, commands, skills, and global instructions are managed separately in the **[assistants module](../assistants/README.md)** and composed for Claude Code, OpenCode, and Codex by `assistants/compose.nix`.

## Package selection

The package source varies by platform:

- **Linux** - `llm-agents.packages.claude-code` from the `llm-agents` flake input
- **macOS** - `pkgs.unstable.claude-code`
- **Fallback** - `pkgs.claude-code`

## Contents

- **[LSP configuration](LSP.md)** - Language server integration via the plugin system; 14 servers across 10 language modules, contributed by each language module via the `claude-code.lspServers` option
- **[MCP servers](../mcp/README.md)** - Shared MCP servers (Context7, Exa, Cloudflare, NixOS, Svelte, plus conditional Playwright) defined in the shared MCP module and delivered to Claude Code via `~/.config/mcp/mcp.json`
- **Permissions** - Plain `claude` uses Claude Code's default permission behaviour. Use `claude-fenced` for the Fence-isolated entry point.
- **ccstatusline** - Status bar integration reporting active session state

## Fenced mode

Claude Code's internal permissions are not managed here. This module provides
`claude-fenced`, which runs Claude through Fence with
`--dangerously-skip-permissions` so Fence is the single permission boundary for
that entry point.

The old Claude Code permission policy and PreToolUse auto-approve hook were
removed. Fence is the maintained isolation and command policy for the fenced
entry point.
