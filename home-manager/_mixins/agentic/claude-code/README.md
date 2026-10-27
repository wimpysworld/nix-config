# Claude Code module

Claude Code with LSP integration, MCP servers, a [Fence](../fence)-isolated entry point, and a ccstatusline status bar.

Home Manager enables this module on workstations. Default servers keep Codex, Pi Agent, generated agent resources, and shared MCP data, but do not install Claude Code or `claude-fenced`.

Agents, commands, skills, and global instructions are managed separately in the **[assistants module](../assistants/README.md)** and composed for Claude Code, OpenCode, Codex, and Pi Agent by the assistants mixin.

## Authentication

On personal physical computers, the `claude` launch wrapper reads the managed `ANTHROPIC_API_KEY` secret when Claude Code starts. The wrapper exports the key only to the Claude Code process and its children.

The normal and fenced launch paths use the same credential wrapper. The fenced path reads the secret inside Fence, so the key does not enter Fence arguments.

Claude Code asks "Do you want to use this API key?" the first time it sees a key and stores the answer in `~/.claude.json` under `customApiKeyResponses`, keyed by the last 20 characters of the key. A rejected key is ignored on every later launch with no message. On personal computers a Home Manager activation step runs after sops-nix decrypts the secret. It approves the key, removes any rejection, sets `hasCompletedOnboarding`, deletes `oauthAccount` from `~/.claude.json`, and removes `~/.claude/.credentials.json`. The API key is then the only credential. Run `/login` to restore the subscription on that host. The status line replaces the 5h and weekly usage segments on personal computers with ccstatusline's `session-cost` widget, the estimated session spend in USD, because the usage segments read the subscription token.

Do not set `forceLoginMethod`. It restricts the login method and, since Claude Code 2.1.146, blocks sessions authenticated by `ANTHROPIC_API_KEY`.

Work hosts do not receive the API key and keep Claude subscription authentication. The Claude ACP adapter does not use this wrapper.

## Package selection

The package source varies by platform:

- **Linux** - `llm-agents.packages.claude-code` from the `llm-agents` flake input
- **macOS** - `pkgs.unstable.claude-code`
- **Fallback** - `pkgs.claude-code`

## Contents

- **[LSP configuration](LSP.md)** - Language server integration via the plugin system; 14 servers across 10 language modules, contributed by each language module via the `claude-code.lspServers` option
- **[MCP servers](../mcp/README.md)** - Shared MCP servers (Codex, Context7, Exa, and Linear) defined in the shared MCP module and delivered to Claude Code via `~/.config/mcp/mcp.json`
- **Fence** - `claude-fenced` runs Claude Code under the shared Fence permission and isolation policy.
- **ccstatusline** - Status bar integration reporting active session state

## Agent Tripwire

Claude Code receives the portable `communication-rules` skill from the assistants module. Global instructions load it by name, and hook adapters use the complete skill body without frontmatter.

Tripwire uses Claude Code settings hooks. `SessionStart` and `UserPromptSubmit` remind without blocking. `PreToolUse` gates outgoing writes, edits, Bash prose side effects, and configured post-capable MCP tools. Where final-response correction is enabled, the native `Stop` surface scans final assistant prose and asks Claude Code to revise without showing trigger details.

The module appends Tripwire hooks and keeps existing MCP config, status line, LSP, wrappers, Fence entry point, and local policy intact. There is no Claude Code command, flag, environment variable, allow rule, or prompt escape that bypasses Tripwire. Operator recovery is still available through normal config disablement, such as `disableAllHooks`, or by rebuilding without the Agent Tripwire mixin.

## Fenced mode

This module provides `claude-fenced`, which runs Claude Code through Fence with
`--dangerously-skip-permissions`. Fence is the managed filesystem, network, and
command policy provider for that entry point.

When `NOUGHTY_CLAUDE_BYPASS=1` is set (`claude-fenced`), the launch wrapper
exports `CLAUDE_CODE_SANDBOXED=1` and records project trust in `~/.claude.json`
(or `$CLAUDE_CONFIG_DIR/.claude.json` when `CLAUDE_CONFIG_DIR` is set) for the
canonical working directory (`pwd -P`), the current Git worktree root
(`git rev-parse --path-format=absolute --show-toplevel`), and the main Git
repository root (the parent of `git rev-parse --path-format=absolute
--git-common-dir`). If every candidate path already has
`hasTrustDialogAccepted = true`, the wrapper skips rewriting the state file.
Plain `claude` does not modify project trust at launch.

## Project trust

Home Manager activation pre-seeds `hasTrustDialogAccepted = true` in
`~/.claude.json` for the configured development roots:

```text
~/Chainguard
~/Chainguard/_worktrees
~/Chainguard/mono
~/Chainguard/stereo
~/Chainguard/cg-github
~/Chainguard/infra
~/Development
~/Development/_worktrees
~/Volatile
~/Zero
~/Zero/nix-config
```

Activation also sets `hasTrustDialogAccepted = true` on every existing
`.projects` entry in `~/.claude.json` whose path equals or starts with
`~/Chainguard/`, `~/Development/`, `~/Volatile/`, or `~/Zero/`. This repairs
stale `hasTrustDialogAccepted: false` entries left behind by earlier
`IS_DEMO=1` sessions while keeping all other project and top-level state intact.
