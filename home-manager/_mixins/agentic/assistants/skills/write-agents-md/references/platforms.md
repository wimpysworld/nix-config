# Platform discovery and overrides

Per-platform rules for AGENTS.md and its legacy variants. Use this to know which files to read on discovery and which to write.

## Canonical filenames

| Platform       | Primary        | Override / local     | Path-scoped rules                        | Disable                                           |
| -------------- | -------------- | -------------------- | ---------------------------------------- | ------------------------------------------------- |
| Codex          | `AGENTS.md`    | `AGENTS.override.md` | none                                     | `--no-project-doc`, `CODEX_DISABLE_PROJECT_DOC=1` |
| Claude Code    | `CLAUDE.md`    | `CLAUDE.local.md`    | `.claude/rules/*.md`                     | `claudeMdExcludes` (monorepo settings)            |
| Cursor         | `.cursorrules` | none                 | `.cursor/rules/*.mdc`                    | none                                              |
| GitHub Copilot | `AGENTS.md`    | none                 | `.github/instructions/*.instructions.md` | none                                              |
| Aider          | configured     | none                 | none                                     | n/a (file is opt-in)                              |
| Gemini CLI     | configured     | none                 | none                                     | n/a (file is opt-in)                              |
| Pi Agent       | `AGENTS.md`    | none                 | none                                     | n/a (Pi 0.75.3 does not read AGENTS.md natively)  |

## Discovery order

- **Codex.** Walks from repo root down to the current working directory, plus the global file at `~/.codex/AGENTS.md`. First non-empty file per directory wins. Concatenates root-first. Closer directory overrides root. User chat prompts override AGENTS.md.
- **Claude Code.** Walks ancestors up at session start and loads each `CLAUDE.md` it finds. Descendants load lazily on first read of a file beneath them. Home file `~/.claude/CLAUDE.md` applies globally. `.claude/rules/*.md` load on demand when a referenced path matches. Last loaded wins.
- **Cursor.** Project-only; no nesting. `.cursor/rules/*.mdc` files carry their own YAML frontmatter for path globs.
- **Aider, Gemini CLI.** Single file configured in `.aider.conf.yml` (`read: AGENTS.md`) or `.gemini/settings.json` (`context.fileName`).
- **Pi Agent.** Does not auto-load AGENTS.md in 0.75.3. The repo includes the file in context manually or relies on Pi extensions that share Pi's repo.

## Consolidation discovery list

Search the repo for all of these when consolidating:

```
AGENTS.md
AGENTS.override.md
CLAUDE.md
CLAUDE.local.md
.claude/rules/*.md
.cursorrules
.cursor/rules/*.mdc
.github/instructions/*.instructions.md
```

Plus any file referenced by:

- `.aider.conf.yml` (`read:`)
- `.gemini/settings.json` (`context.fileName`)
- Codex `project_doc_fallback_filenames` config

## Conflict and precedence rules

- User chat prompts override AGENTS.md on every platform.
- Closer directory overrides root on Codex and Claude Code.
- Codex `AGENTS.override.md` replaces the AGENTS.md at the same level.
- Claude Code `CLAUDE.local.md` is gitignored by convention; use it for per-developer overrides, not shared rules.
- Cursor `.mdc` rules are the only vendor variant that reads YAML frontmatter; otherwise the spec is plain Markdown.

## Size and truncation

- Codex: `project_doc_max_bytes` defaults to 32 KiB; content beyond is truncated silently.
- Claude Code: ≤200 lines per file is the documented target; adherence drops sharply beyond that.
- Cursor and others: no hard limit, but the same context-window economics apply.
