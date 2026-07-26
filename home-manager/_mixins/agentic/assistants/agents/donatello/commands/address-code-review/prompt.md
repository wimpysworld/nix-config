## Address Code Review

Evaluate review feedback, then implement or decline each finding with rationale. Commit each accepted finding as it lands. This command orchestrates; it never implements in this context.

### Input

`$ARGUMENTS` is a pull request URL or number, a path to a local file holding review feedback, or the feedback pasted directly as text. If it is blank, ask which of those you have, then wait.

For a pull request, fetch the review comments with dedicated `gh` subcommands such as `gh pr view`. Raw `gh api` is denied; use `gh-api-safe` for raw reads.

### Categories

| Category | Action | Examples |
|----------|--------|----------|
| 🚨 **Critical** | Must fix | Logic errors, crashes, security vulnerabilities, data corruption |
| 🛡️ **Robustness** | Should fix | Unhandled edge cases, missing error handling, race conditions |
| 🔧 **Quality** | Consider | Clear maintainability wins, measurable performance gains |
| 📝 **Style** | Usually skip | Subjective preferences, complex refactors for marginal gains |

### Decisions

| Decision | When |
|----------|------|
| ✅ **Implement** | Critical bugs, security issues, high value + low complexity |
| ⚠️ **Defer** | High value but needs broader refactoring or benchmarks first |
| ❌ **Decline** | False positive, style preference, complexity exceeds benefit |
| 🔍 **Investigate** | Unclear if real issue, needs testing to validate |

### Process

1. Invoke `less-is-more` to reload the Communication Rules before starting. Codex uses `$less-is-more`; slash-command runtimes use `/less-is-more`. If the platform cannot expand a command, apply the rules restated below instead
2. Read the feedback and split it into discrete findings. Categorise and decide each one
3. Group the findings by the files they touch. Findings that touch the same file run in sequence, never in parallel, or their edits clobber each other. Different groups may run in parallel
4. Dispatch one fresh sub-agent per finding, in that order. Never hand two findings to one sub-agent. Fresh context per finding keeps attention high and changes small
5. When a finding's fix depends on or conflicts with a fix already applied, re-evaluate it against the current state of the code rather than applying it blind
6. Commit after each finding that produced a change, one commit per finding. Stage explicitly with path-limited `git add -- <path>` using the files in that finding's report. Never `git add .`, `-A`, or `-u`. Run `draft-commit-message` for the message, or invoke `make-commit` to draft and commit in one step. Commit from this context only, one finding at a time, so parallel sub-agents never contend for the index
7. Stop after the final commit. Never push

Every report and commit message must follow the Communication Rules: concise (each fact once), British English spelling, active voice, lead with the conclusion, no banned words (filler, pleasantries, hedges, LLM tells), and no em or en dashes.

### Per-Finding Output

```markdown
## Finding #[X]: [Brief description]

**Category**: 🚨|🛡️|🔧|📝
**Decision**: ✅|⚠️|❌|🔍
**Rationale**: [1-2 sentences]
**Files**: `path/to/file`
**Commit**: <short-sha, or none>
```

### Summary Report

```markdown
Answer: <ready to merge, or another round needed, in one sentence>
Decisions: ✅ X implemented | ⚠️ X deferred | ❌ X declined | 🔍 X investigating
Key fixes:
- <top 2-3 improvements, each with its commit sha>
Deferred:
- <item and priority, or none>
```

### Constraints

- Be decisive; never implement merely because someone suggested it
- Challenge suggestions that misunderstand domain context
- Record decline rationale so the reasoning survives
- Verify each critical fix resolves the issue it claims to
- Time-box investigation of non-critical items
- Committing is in scope; pushing is not
