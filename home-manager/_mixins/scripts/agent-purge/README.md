# agent-purge

Removes the chat history, caches, logs and temporary files of Claude Code, Codex, Pi and OpenCode. Every run covers all four clients, the shared agent temporary files, and the review reports.

The script prints the number of files and their total size for each group, then asks `Remove these files? [y/N]`. It deletes only on `y` or `yes`. Any other answer, or end of input, exits without deleting. To run it without a terminal, pipe the answer in: `echo y | agent-purge`.

It refuses to run inside the Fence sandbox, because the sandbox hides the host `/tmp` and the host processes. It also refuses to run while a client process runs. `--force` overrides the process check only.

## What it removes

| Group | Paths |
| --- | --- |
| Claude Code | In each `~/.claude/projects/<project>/`: `*.jsonl*` transcripts, `sessions-index.json`, and the per-session `<uuid>/` directories. A project directory goes only when it is empty afterwards. Under `~/.claude/`: `history.jsonl`, `file-history/`, `paste-cache/`, `image-cache/`, `shell-snapshots/`, `session-env/`, `tasks/`, `teams/`, `todos/`, `plans/`, `debug/`, `logs/`, `statsig/`, `uploads/`, `dev-mods/`, `usage-data/`, `feedback-bundles/`, `feedback/drafts/`, `cache/`, `stats-cache.json`, `backups/`. Also `~/.claude.json.backup.*`, `~/.cache/claude-cli-nodejs/`, `~/.cache/fence-share/claude-<uid>/`, `/tmp/claude-<uid>/` and `/tmp/claude-mcp-config.*.json`. |
| Codex | In both `~/.codex/` and `~/.config/codex/`: `history.jsonl`, `session_index.jsonl`, `sessions/`, `archived_sessions/`, `thread_history_1.sqlite*`, `state_5.sqlite*`, `logs_2.sqlite*`, `log/`, `shell_snapshots/`, `.tmp/`, `tmp/`, `cache/`, `plugins/cache/`, `models_cache.json`, `cloud-config-bundle-cache.json`, `cloud-requirements-cache.json`. |
| Pi | In `~/.pi/agent/`: `sessions/`, `run-history.jsonl`, `mcp-cache.json`, `cache/`, `pi-debug.log`, `crashes.json`, `mcp.log`, `tmp/`. |
| OpenCode | Every session, through `opencode session delete`. Then `~/.local/share/opencode/snapshot/`, `log/` and `storage/`, and `~/.local/state/opencode/prompt-history.jsonl`. |
| Shared temporary files | `~/.cache/fence-share/tmp.*`, `agent-plans/` and `agent-research/` under both `/tmp` and `~/.cache/fence-share/`, and `/tmp/agent-communication-rules/`, `/tmp/fence-wayland-runtime.*` and `/tmp/fence-chromium.*`. Entries in `/tmp` are removed only when the user owns them. |
| Review reports | `~/.local/state/agent-reviews/`. |

The XDG paths follow `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME` and `XDG_CACHE_HOME`.

## What it protects

The script deletes only the paths above, so everything else stays. That includes:

- credentials, such as `~/.claude/.credentials.json` and every `auth.json` and `mcp-auth.json`;
- settings, such as `~/.claude.json`, `config.toml` and `policy-limits.json`;
- every Home Manager-managed file and every path in `~/.local/state/agentic/assistants/manifest.json`;
- memory: `~/.claude/projects/*/memory/`, `~/.claude/agent-memory/`, and the Codex `memories*`, `goals_1.sqlite*` and `queue_1.sqlite*` files;
- live session state: Claude Code `sessions/`, `daemon/` and `jobs/`, and the Codex `thread-writer-locks/`;
- the Pi packages (`git/`, `npm/`, `npm-global/`) and the Pi `state/`;
- the OpenCode database file `opencode.db`, which also holds credentials.

OpenCode keeps its sessions in `opencode.db`. The script lists the root sessions with a read-only `opencode db` query, because `opencode session list` shows only the sessions of the current project. When `opencode` is not on `PATH`, or the query fails, the sessions are kept and the summary says so.

The script makes no backups.

## Testing

`AGENT_PURGE_TMP_ROOT` replaces `/tmp`. It exists for testing only, so a test can point `HOME`, the XDG variables and this variable at a fake directory tree.
