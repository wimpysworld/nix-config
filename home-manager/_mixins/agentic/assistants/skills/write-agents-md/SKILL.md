---
name: write-agents-md
description: Use when creating, updating, consolidating, or reviewing an AGENTS.md (or CLAUDE.md, CLAUDE.local.md, .claude/rules/*.md, .cursorrules, .cursor/rules/*.mdc, AGENTS.override.md, or .github/instructions/*.instructions.md) project instruction file. Covers the open agents.md spec, Codex precedence rules, Claude Code memory loading, and migration from legacy formats. Use even if the user only says "instructions", "rules", "project memory", or names a single legacy filename.
---

# Write AGENTS.md

Author and maintain project instruction files (AGENTS.md and its vendor variants) that agents read every session. One artefact, three flows: create from scratch, targeted update, or consolidate scattered files.

## Decide first

- **Create** vs **update** vs **consolidate**. Create when no instruction file exists in scope. Update when changes are narrow. Consolidate when more than one instruction file covers the same scope; see `references/platforms.md` for the discovery list.
- **Root** vs **nested**. Put repo-wide rules at the root. Put module-specific rules in the relevant subdirectory's `AGENTS.md`. Nearest file wins on Codex; descendants load lazily on Claude Code. Direct user prompts override either.
- **Edit** vs **delete**. Never delete an existing instruction file without explicit user confirmation; propose deletions in the changelog.

## Mechanics

- Filename: `AGENTS.md` at the repo root by default. See `references/platforms.md` for vendor variants, discovery order, and override files.
- Format: plain Markdown. No YAML frontmatter. No required headings.
- Loading: every session, every file in the walk. Token cost is real, prompt-cached after first load. Bloat erodes adherence.
- Size: 50-200 lines for a root file; nested files much shorter. Codex truncates at 32 KiB (`project_doc_max_bytes`). Claude Code degrades adherence beyond ~200 lines per file.
- Precedence: user chat prompts override AGENTS.md. Closer directories override the root.

## Sections

Use the canonical set in `references/sections.md`. Skip any section with no project-specific content. Typical headings:

- Project overview (one sentence)
- Setup
- Build and test
- Code style
- Testing
- PR and commit conventions
- Architecture notes
- Security and secrets
- Gotchas

## Content rules

- Imperatives, not descriptions. "Use TypeScript strict mode for new files" beats "the project uses TypeScript".
- Apply the removal test: "would removing this rule cause the agent to make mistakes?" If no, cut it.
- No language defaults the model already knows from reading the code.
- No persona, role, or tone instructions; those belong in agent system prompts.
- No generic LLM boilerplate ("be helpful", "ask clarifying questions").
- No time-sensitive content (dates, version numbers that drift).
- No frontmatter. Plain Markdown. The Cursor `.mdc` exception is the only vendor parser that reads YAML; see `references/platforms.md`.
- Runnable commands only. Test them before committing.
- Flag and resolve self-contradictions before edit; arbitrary choices waste tokens.

## Consolidation flow

1. Discover instruction files using the list in `references/platforms.md`.
2. Extract project-specific rules from each; drop duplicates and generic advice.
3. Flag conflicts for user resolution; do not silently pick a winner.
4. Preserve runnable commands verbatim.
5. Propose the canonical target (`AGENTS.md` at root) and the legacy files to delete, import-shim, or symlink. Prefer `@AGENTS.md` import shims (Claude Code, Gemini CLI) over symlinks to avoid double-loading; symlink only where no import syntax exists. See `references/migration.md`.
6. Require explicit confirmation before deleting any file.

## Review

Assessment scale:

| Rating         | Meaning                                                      |
| -------------- | ------------------------------------------------------------ |
| ✅ Strong      | Follows best practices, no significant issues                |
| ⚠️ Adequate    | Functional but has improvement opportunities                 |
| 🔧 Needs Work  | Missing high-value patterns or contains ineffective patterns |
| ❌ Restructure | Fundamental issues requiring significant revision            |

Review criteria specific to AGENTS.md (agent-prompt criteria belong in `write-assistant`):

| Criterion    | High value                            | Low or no value                       |
| ------------ | ------------------------------------- | ------------------------------------- |
| Voice        | Imperative, specific                  | Descriptive, generic                  |
| Commands     | Runnable, copy-pasteable              | Placeholder or untested               |
| Scope        | Project-specific                      | Restates language defaults            |
| Size         | Within 50-200 lines                   | Long sections an agent will skim past |
| Structure    | Canonical sections, no empty headings | Custom taxonomy, persona text         |
| Removal test | Each rule changes behaviour           | Could be cut without loss             |

## Output

When invoked to **create**, produce the new file at the requested path. Pure Markdown. No frontmatter.

When invoked to **update** or **consolidate**, produce the edited file plus a short changelog:

```markdown
## <path>

**Rating:** ✅|⚠️|🔧|❌
**Conflicts:** <list contradictions surfaced before edit, or "None">
**Issues:** <table: issue / criterion / recommendation>
**Changes made:** <bullet list>
**Files to delete (require confirmation):** <list, or omit>
```

If invoked as a sub-agent for routing reasons, follow the response contract from `delegate-task`.

## Anti-patterns

- Frontmatter on AGENTS.md (the spec is plain Markdown).
- Persona or tone text (belongs in agent system prompts; see `write-assistant`).
- File-by-file codebase tours; long API documentation (link instead).
- Generic LLM instructions.
- Time-sensitive content (dates, drifting version numbers).
- Empty sections kept "for completeness".
- Restating standard language conventions.

## References

- `references/platforms.md` - per-platform discovery, override files, disabling, and the full consolidation search list.
- `references/sections.md` - canonical section template with one minimal example each.
- `references/migration.md` - rename, import-shim, and symlink recipes for legacy filenames.

Related skills: `write-skill` (for `SKILL.md` files), `write-assistant` (for agent system prompts).
