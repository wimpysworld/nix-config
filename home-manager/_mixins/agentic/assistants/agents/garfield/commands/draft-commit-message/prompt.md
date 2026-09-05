## Draft Commit Message

Draft the conventional commit message for the staged or current changes. This step drafts only; it never commits.

### Allowed Commands

Run each command separately, no chaining:

- `git status --short --branch` - staging state and current branch
- `git diff --staged` - view staged changes
- `git diff` - view unstaged changes when nothing is staged
- `git diff --staged --stat` - summarise staged files only when useful
- `git log --oneline -10` - resolve unknown commit conventions

### Forbidden Commands

These bans govern this drafting step. They do not restrict the command that invoked it.

NEVER execute while drafting:

- `git commit` / `git commit -m` - this step produces the message, the caller commits
- `git branch` - use the status output for the branch name
- `git add` - this step never stages; the caller stages before invoking it
- `git checkout` / `git reset` - never change the working tree
- Command chaining with `&&`, `;`, or `|`

### Process

1. Read `communication-rules` first unless its complete, current instructions are in this context. Apply it before drafting
2. Read `contribution-voice` first unless its complete, current instructions are in this context. Apply it before drafting anything. It governs the structure of text published under the user's name. If the platform cannot load a skill, continue with the rules restated below
3. When invoked inline, reuse known intent, conventions, status and staged evidence. Run allowed commands only for missing context. For standalone drafting, start with `git status --short --branch` and `git diff --staged`.
4. If nothing is staged, use `git diff` and read relevant untracked files to describe the current changes. If there are no changes, report that there is nothing to draft.
5. If Garfield's commit rules are absent from context, read its agent prompt without launching an agent. Apply its Type Selection, Scope Selection and commit-message Constraints. Reuse known scope conventions instead of repeating history discovery.
6. Output the commit message in a fenced code block. This block is the deliverable and must reach the caller unchanged

The commit message itself must follow the Communication Rules: concise (each fact once), British English spelling, active voice, lead with the conclusion, no banned words (filler, pleasantries, hedges, LLM tells), and no em or en dashes.

### Relay Contract (for invoking agent)

The wording of the fenced code block is fixed. Relay it under the `delegate-task` relay rules: verbatim, never rewritten.

- Preserve the fencing exactly
- No preamble or trailing commentary unless a follow-up needs it
- When a `make-*` command invoked this drafting step, that command consumes the block as its commit message source; return the block and let the flow continue

### Body Decision

- Include body: multiple files, non-obvious rationale, breaking change
- Skip body: single-purpose change clear from the subject line

### Example

<example_input>
Staged: added null check in auth middleware, updated error message
</example_input>

<example_output>

```
fix(auth): handle missing user email in profile lookup

- Add null check before accessing user.email
- Return descriptive error instead of crashing
```

</example_output>
