# Claude Code module

Claude Code with LSP integration, MCP servers, a [Fence](../fence)-isolated entry point, and a ccstatusline status bar.

Home Manager enables this module on workstations. Default servers keep Codex, Pi Agent, generated agent resources, and shared MCP data, but do not install Claude Code or `claude-fenced`.

Agents, commands, skills, and global instructions are managed separately in the **[assistants module](../assistants/README.md)** and composed for Claude Code, OpenCode, Codex, and Pi Agent by the assistants mixin.

## Package selection

The package source varies by platform:

- **Linux** - `llm-agents.packages.claude-code` from the `llm-agents` flake input
- **macOS** - `pkgs.unstable.claude-code`
- **Fallback** - `pkgs.claude-code`

## Contents

- **[LSP configuration](LSP.md)** - Language server integration via the plugin system; 14 servers across 10 language modules, contributed by each language module via the `claude-code.lspServers` option
- **[MCP servers](../mcp/README.md)** - Shared MCP servers (Context7, Exa, Cloudflare, NixOS, Svelte, plus conditional Playwright) defined in the shared MCP module and delivered to Claude Code via `~/.config/mcp/mcp.json`
- **Fence** - `claude-fenced` runs Claude Code under the shared Fence permission and isolation policy.
- **ccstatusline** - Status bar integration reporting active session state

## Agent Tripwire

Claude Code receives the shared Communication Rules fragment from the assistants module. The fragment is generated once by Nix and reused by the Claude Code instructions and hook adapters.

Tripwire uses Claude Code settings hooks. `SessionStart` and `UserPromptSubmit` remind without blocking. `PreToolUse` gates outgoing writes, edits, Bash prose side effects, and configured post-capable MCP tools. Where final-response correction is enabled, the native `Stop` surface scans final assistant prose and asks Claude Code to revise without showing trigger details.

The module appends Tripwire hooks and keeps existing MCP config, status line, LSP, wrappers, Fence entry point, and local policy intact. There is no Claude Code command, flag, environment variable, allow rule, or prompt escape that bypasses Tripwire. Operator recovery is still available through normal config disablement, such as `disableAllHooks`, or by rebuilding without the Agent Tripwire mixin.

## Fenced mode

This module provides `claude-fenced`, which runs Claude Code through Fence with
`--dangerously-skip-permissions`. Fence is the managed filesystem, network, and
command policy provider for that entry point.
