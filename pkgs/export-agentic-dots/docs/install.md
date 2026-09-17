# Install selected client files

The exporter only creates a review tree. It does not change a client installation.

1. Run `just export-agentic-dots <destination>` from the source repository.
2. Review `catalogues/resources.json` and `.agentic-dots-manifest.json`.
3. Confirm that `sourceRevision` names the expected commit and includes `-dirty` for a dirty worktree.
4. Back up the target client configuration.
5. Copy one client root into the matching home directory.
6. Merge settings when the target already has a configuration file.

For example, copy files from `pi/.pi/agent/` into `~/.pi/agent/`. Copy files from `codex/.codex/` into `~/.codex/`. Do not copy the outer client directory.

Claude Code reads the exported `.mcp.json` at project scope. Copy `claude/.mcp.json` into a trusted project only after review.

OpenCode and Codex read `CONTEXT7_API_KEY` and `LINEAR_API_KEY` from the recipient environment. The export contains variable names only.

Pi and Claude Code include only the unauthenticated Exa MCP server. Add authenticated servers with each client's supported command after the recipient authenticates.

Pi installs the pinned `pi-mcp-adapter` and `pi-subagents` packages from `settings.json` at client start. Review npm package installation policy before first use.

Provider route files contain exact model identifiers from the source setup. The recipient must have access to those models or customise the route files.

The Communication Rules scanner is source-only. Run `python3 integrations/communication-rules/scanner.py --help` before you connect it to a client hook.
