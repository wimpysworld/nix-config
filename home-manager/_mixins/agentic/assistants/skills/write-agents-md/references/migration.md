# Migration recipes

Rename legacy instruction files to `AGENTS.md` and keep older tools working via the smallest possible shim. Always require explicit user confirmation before deleting or overwriting.

## Prefer imports over symlinks

Symlinking a vendor file to `AGENTS.md` causes agents that read both names (e.g. Claude Code reading `CLAUDE.md` while another tool reads `AGENTS.md`) to load the same content twice and waste context. Use a one-line import file when the vendor supports it; fall back to a symlink only when it does not.

## Common shims

| From             | Recommended shim                  | Why                                                              |
| ---------------- | --------------------------------- | ---------------------------------------------------------------- |
| `CLAUDE.md`      | File containing only `@AGENTS.md` | Claude Code resolves `@path` imports; avoids double-loading.     |
| `GEMINI.md`      | File containing only `@AGENTS.md` | Gemini CLI resolves `@path` imports the same way.                |
| `AGENT.md`       | `ln -s AGENTS.md AGENT.md`        | No import syntax; symlink is safe because only one file is read. |
| `.cursorrules`   | `ln -s AGENTS.md .cursorrules`    | Plain text, no import syntax.                                    |
| `.windsurfrules` | `ln -s AGENTS.md .windsurfrules`  | Plain text, no import syntax.                                    |
| `.clinerules`    | `ln -s AGENTS.md .clinerules`     | Plain text, no import syntax.                                    |

For the import shims, the file must contain only the `@AGENTS.md` line and a short comment instructing maintainers not to add other content; any extra prose duplicates doctrine and re-introduces drift.

Example `CLAUDE.md`:

```markdown
<!-- Vendor shim. Do not add content here; edit AGENTS.md instead. -->

@AGENTS.md
```

Run shim commands from the repo root.

## Codex override workflow

Codex supports `AGENTS.override.md` to replace `AGENTS.md` at the same directory level. Use it for:

- Per-developer experiments staged before sharing.
- Temporary rule changes during incident response.
- Repository forks that need different rules without diverging the canonical file.

`AGENTS.override.md` should be gitignored unless the team agrees to share it.

## Claude Code local file

`CLAUDE.local.md` is the per-developer counterpart on Claude Code. Gitignore by convention. Use for the same reasons as Codex overrides.

## Path-scoped rules

For rules that apply only inside a subdirectory, prefer:

- A nested `AGENTS.md` in that subdirectory (portable across Codex and Claude Code).
- `.claude/rules/<topic>.md` referenced by path (Claude Code only).
- `.cursor/rules/<topic>.mdc` with `globs:` frontmatter (Cursor only).

Avoid path-scoped rules in the root file; they bloat the always-loaded surface and reduce adherence.

## Consolidation order of operations

1. Read all files in the discovery list.
2. Diff their content; flag conflicts before merging.
3. Produce a single canonical `AGENTS.md`.
4. Propose deletions or symlinks per the table above.
5. Stop and confirm before any `rm` or `mv`.
