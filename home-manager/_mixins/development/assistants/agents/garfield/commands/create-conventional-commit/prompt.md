## Create Conventional Commit

Write a commit message for staged changes. Output only - never execute commits.

### Allowed Commands

Run each command separately (no chaining):

- `git status` - shows staging state AND current branch (line 1: "On branch X")
- `git diff --staged` - view staged changes
- `git diff --staged --stat` - summarise staged files
- `git log --oneline -10` - recent commits for style reference

### Forbidden Commands

**NEVER execute:**

- `git commit` / `git commit -m` - output message only, user commits manually
- `git branch` - use `git rev-parse --abbrev-ref HEAD` for branch name instead
- `git add` / `git checkout` / `git reset` - no staging or working tree changes
- Command chaining with `&&`, `;`, or `|`

### Process

1. Run allowed commands individually to gather context
2. If nothing staged, summarise recent implementation work from conversation
3. Apply type selection from agent definition
4. **Output commit message in a code block** - user will copy and commit
5. **Output a ready-to-run command** immediately after the message block - user copies and runs to commit

### Body Decision

- **Include body**: Multiple files, non-obvious rationale, breaking change
- **Skip body**: Single-purpose change clear from subject line

### Example

<example_input>
Staged: Added null check in auth middleware, updated error message
</example_input>

<example_output>
```
fix(auth): handle missing user email in profile lookup

- Add null check before accessing user.email
- Return descriptive error instead of crashing

Fixes #234
```

```fish
git commit -m "fix(auth): handle missing user email in profile lookup

- Add null check before accessing user.email
- Return descriptive error instead of crashing

Fixes #234"
```
</example_output>
