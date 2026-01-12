---
agent: "garfield"
description: "Create Commit ✍️"
---

## Create Conventional Commit

Write a commit message for staged changes (or recent work if nothing staged).

### Process

1. Check `git diff --staged` for staged changes
2. If nothing staged, summarise recent implementation work
3. Apply type selection from agent definition
4. Output commit message only—ready for `git commit -m`

### Body Decision

- **Include body**: Multiple files changed, non-obvious rationale, breaking change
- **Skip body**: Single-purpose change clear from subject line

### Example

<example_input>
Staged: Added null check in auth middleware, updated error message
</example_input>

<example_output>
fix(auth): handle missing user email in profile lookup

- Add null check before accessing user.email
- Return descriptive error instead of crashing

Fixes #234
</example_output>
