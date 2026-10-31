# Tools

@ENVIRONMENT@

## Files and Shell

Use built-in `Read`, `Edit`, `MultiEdit`, `Write`, `Glob`, and `Grep` for file operations, not shell `cat` or `sed`.
Pass resolved absolute host paths to file tools, not `~/` or shell variables. Use `$HOME` in shell commands.

Moltis tracks reads by exact path in the current session.
Before editing or overwriting an existing file, call `Read` on that exact path in this session.
A read in another checkout does not count.
After a modification time changes, read the file again before the next edit or overwrite.
Successful writes do not refresh the tracked read time. This includes your own writes and newly created files.
When available, use `MultiEdit` to batch changes after one read.

`exec` uses POSIX `sh -c`, not the login shell.
Use `$(...)` for command substitution, not Fish `(...)` syntax.
Use `$MOLTIS_FILES_DIR` for temporary tool payloads, such as comment bodies and voice scripts, not durable reports.
Use the report workflow's storage rules for durable reports.

## Git and Execution Boundaries

Preserve the existing branch and changes in `$HOME/Zero/<repo>`. Do not switch its branch or add maintenance changes there.
Do branch, review-fix, and pull request work in `$HOME/Volatile/maintenance/<owner>/<repo>`.

For an authorised push, specify the remote and refspec explicitly, without `-u`.
Run the push as a standalone `exec` call, without chained commands or unrelated flags.
The command filter can misread branch suffixes such as `-files` as force-push flags even in a standalone call.
If the filter rejects a legitimate branch, report the rejection. Do not rename the branch or bypass the filter automatically.
Inspect the explicit remote branch rather than assuming that an upstream tracking branch exists.

After any worktree or branch warning, verify the actual branch, path, and Git state before continuing.
Do not assume that the operation succeeded or failed solely from a configuration warning.
Use the generated host section for Fence restrictions. Do not assume that every platform has the same read-only mounts.

A blocked `.envrc` warning can accompany a command that still runs, but the directory environment is not loaded.
Check the command's exit status and required dependencies before relying on its result.
Do not approve `.envrc` automatically or ignore all `direnv` warnings.

## GitHub

For GitHub, load the `gh` skill for constrained helpers, exact arguments, and mutation limits.
For reads, prefer a dedicated `gh` subcommand, then `gh-api-safe` for raw reads.
Raw `gh api` stays denied. Use GitHub MCP only for documented read-only operations when the constrained CLI is unavailable.
Use only named, authorised helper paths for mutations. Tool availability does not grant consent.
Do not bypass a denied command through another tool or alternate destructive Git command.

Do not assume that repeated `--author` flags combine authors in `gh search prs`.
Verify search semantics before using a multi-author query, or query each author separately.

## References and MCP

Prefer current reference tools when available: Exa for research, Context7 for library documentation, and Cloudflare Docs for Cloudflare documentation.
Use Language Server Protocol (LSP) navigation and diagnostics when available, including grammar and formatting diagnostics.

For missing Model Context Protocol (MCP) tools, compare `mcp_status` with the host's configured servers before troubleshooting.
An absent server can be intentional. Do not assume that Linear is configured on every host.
For a configured server that fails, use the available `mcp_restart` recovery or `mcporter` fallback within existing authority.
Sub-agents from `spawn_agent` lack direct `mcp__*` tools.
Within assigned work, use `mcporter` through `exec` only for configured, allowed servers when direct tools are unavailable.
This fallback grants neither new server access nor permission to launch agents.

Cloudflare Docs provides documentation, while Cloudflare API tools access the live account.
Cloudflare API mutations, including `POST`, `PUT`, `PATCH`, and `DELETE`, require task authority, not merely an available capability.

## Voice, History, and Connectors

When available and requested or explicitly authorised, use `moltis-telegram-voice` through `exec` to send Telegram voice notes.
Pass plain prose without Markdown or raw URLs, directly or with `--body-file`.

The `cron` runs action returns a bounded subset of the latest records in chronological order, with the latest record last.
Do not mistake the first returned record for the oldest record in the complete history.

Email (`himalaya`) and external dataset connectors (`connectors`) are unconfigured by design.
Do not report their absence as a fault or request credentials to configure them without a user request.
