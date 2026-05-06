# Claude Code module

Claude Code with LSP integration, MCP servers, permission policy, and a ccstatusline status bar.

Agents, commands, skills, and global instructions are managed separately in the **[assistants module](../assistants/README.md)** and composed for Claude Code, OpenCode, and Codex by `assistants/compose.nix`.

## Package selection

The package source varies by platform:

- **Linux** - `llm-agents.packages.claude-code` from the `llm-agents` flake input
- **macOS** - `pkgs.unstable.claude-code`
- **Fallback** - `pkgs.claude-code`

## Contents

- **[LSP configuration](LSP.md)** - Language server integration via the plugin system; 14 servers across 10 language modules, contributed by each language module via the `claude-code.lspServers` option
- **[MCP servers](../mcp/README.md)** - Shared MCP servers (Context7, Exa, Cloudflare, NixOS, Svelte, plus conditional Playwright) defined in the shared MCP module and delivered to Claude Code via `~/.config/mcp/mcp.json`
- **[Permission policy](PERMISSIONS.md)** - Three-tier allow/ask/deny rules with prefix matching; covers 12 tool domains, read denials for credentials, and bash command categories
- **ccstatusline** - Status bar integration reporting active session state

## Sub-agent permission issues

Permission rules from `settings.json` do not propagate reliably to sub-agents (Task tool). Four overlapping bugs remain open as of March 2026:

| Issue | Problem |
|-------|---------|
| [#18950](https://github.com/anthropics/claude-code/issues/18950) | `permissions.allow` rules not loaded into sub-agent context. Sub-agents spawn with empty permission state. In-session approvals from the parent are not passed down. |
| [#25000](https://github.com/anthropics/claude-code/issues/25000) | Symmetric failure: `permissions.deny` rules also ignored. A denied `Bash` tool in the parent still executes freely in sub-agents. |
| [#21460](https://github.com/anthropics/claude-code/issues/21460) | `PreToolUse` hooks do not fire for sub-agent tool calls. Hooks run at process level; sub-agents spawn new processes without hook configuration. |
| [#28584](https://github.com/anthropics/claude-code/issues/28584) | Regression since v2.1.56: sub-agents prompt on every tool call (`Read`, `Glob`, `Grep`) regardless of parent approvals. |

**Practical impact:** the [permission policy](PERMISSIONS.md) documented here governs the parent session only. Sub-agents operate outside these rules.

### Mitigations

Set `permissionMode` explicitly in agent frontmatter for agents you control:

```yaml
---
name: my-agent
permissionMode: bypassPermissions
---
```

For built-in agents (`Explore`, `Plan`, `general-purpose`), shadow them with project-level definitions in `.claude/agents/` that set `permissionMode` explicitly. Project scope overrides user scope, which overrides plugin agents.

Setting `defaultMode: bypassPermissions` in `settings.json` covers dynamically-spawned sub-agents but applies to the parent session too, removing all confirmation prompts.
