# Skill capability

Create or update a repository-local skill through the repository's existing skill source and composition system.

## Author

1. Load `write-skill` and read it in full before editing.
2. Follow its create or update flow, including portable frontmatter, progressive disclosure, references, anti-patterns, and trigger evaluations. Do not reproduce that doctrine here.
3. Inspect nearby skills and the repository's discovery code. Use its source directory, encryption convention, generation step, and registration pattern.
4. Keep one canonical skill tree when the repository already composes it for several clients. Do not copy the tree into generated destinations.

If the repository has no composer, identify the clients it supports and confirm their current repository-scoped discovery paths before choosing a location. Common native paths include:

| Client      | Repository form to verify                                        |
| ----------- | ---------------------------------------------------------------- |
| Claude Code | `.claude/skills/<name>/SKILL.md`                                 |
| Codex       | `.agents/skills/<name>/SKILL.md`                                 |
| OpenCode    | `.opencode/skills/<name>/SKILL.md` or a shared path it discovers |
| Pi          | `.pi/skills/<name>/SKILL.md` or `.agents/skills/<name>/SKILL.md` |

Client versions differ in shared-path discovery. Prefer a shared path only after checking every supported client. Otherwise use the repository's generator or each client's native path while retaining one maintained source where possible.

## Validate

1. Parse the frontmatter and confirm the directory name matches `name`.
2. Run at least three trigger scenarios as required by `write-skill`: one load, one ignore, and one defer or boundary case.
3. Confirm every referenced file exists one level below `SKILL.md`; check required tables of contents and size limits.
4. Evaluate or run the repository composer and inspect the emitted tree for each supported client.
5. Use installed client diagnostics or discovery listings when available. For Codex, confirm `SKILL.md` is a real discovered file when the repository's deployment model requires it.
6. Compare frontmatter, body, references, and invocation name across emitted forms.

Do not call a skill discovered because its source directory exists. Confirm the client-facing output or discovery listing.
