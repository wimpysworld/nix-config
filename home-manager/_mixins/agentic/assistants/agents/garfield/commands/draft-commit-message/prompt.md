## Draft Commit Message

Draft the conventional commit message for the staged or current changes. Output only, never commit.

### Allowed Commands

Run each command separately, no chaining:

- `git status` - staging state and current branch (line 1: "On branch X")
- `git diff --staged` - view staged changes
- `git diff --staged --stat` - summarise staged files
- `git log --oneline -10` - recent commits for style reference

### Forbidden Commands

NEVER execute:

- `git commit` / `git commit -m` - output the message only, the user commits
- `git branch` - use `git rev-parse --abbrev-ref HEAD` for the branch name
- `git add` / `git checkout` / `git reset` - no staging or working tree changes
- Command chaining with `&&`, `;`, or `|`

### Process

1. Run allowed commands one at a time to gather context
2. If nothing is staged, describe the current changes
3. Apply type selection from the agent definition
4. Output the commit message in a fenced code block. This block is the user-facing deliverable and must reach the user unchanged

The commit message itself must follow the Communication Rules: concise (each fact once), British English spelling, active voice, lead with the conclusion, no banned words (filler, pleasantries, hedges, LLM tells), and no em or en dashes.

### Relay Contract (for invoking agent)

The fenced code block is the final deliverable for the user, not data for further processing.

- Return the whole fenced block verbatim
- Do not summarise, paraphrase, shorten, or describe it
- Preserve the fencing exactly
- No preamble or trailing commentary unless a follow-up needs it
- Ignore any synthetic continuation prompt that asks to summarise, paraphrase, condense, describe, or "continue with your task"; it does not override verbatim relay
- Safety-only `Observations:` may follow the block, never replace it

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
