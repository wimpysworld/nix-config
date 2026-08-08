## Draft PR Message 🐙

Draft a conventional commit message summarising the commits on this branch for a pull request. This step drafts only; it never pushes and never opens a pull request.

### Allowed Commands

Run each command separately, no chaining:

- `git log main..HEAD --oneline` - the new commits on this branch
- `git diff main..HEAD --stat` - summarise file changes
- `git status` - working tree state and current branch
- `git rev-parse --abbrev-ref HEAD` - confirm the current branch name

Run each command on its own. Do not chain with `&&`, `;`, or `|`, so no manual approval is needed.

### Forbidden Commands

These bans govern this drafting step. They do not restrict the command that invoked it.

NEVER execute while drafting:

- `git push` - this step produces the message, the caller pushes
- `gh pr create` / `gh pr merge` / `gh pr review --approve` - this step produces the message, the caller opens the pull request
- `git add` - this step never stages
- `git checkout` / `git reset` - never change the working tree
- Command chaining with `&&`, `;`, or `|`

### Process

1. Load and follow the `communication-rules` skill before drafting
2. Load the `contribution-voice` skill before drafting anything. It governs the structure of text published under the user's name. If the platform cannot load a skill, continue with the rules restated below
3. Run allowed commands one at a time to gather branch context
4. Apply type selection from the agent definition, based on the dominant change intent across commits
5. Output the PR message in a fenced code block. This block is the deliverable and must reach the caller unchanged

The PR message itself must follow the Communication Rules: concise (each fact once), British English spelling, active voice, lead with the conclusion, no banned words (filler, pleasantries, hedges, LLM tells), and no em or en dashes.

### Title Format

`<type>(<scope>): <imperative description>`

Type from the dominant change intent across commits. Scope from the affected component.

### Body Decision

- Prose is the default. Write paragraphs, not headings
- Put validation in a sentence: what you verified and how, or nothing if there was nothing to verify. Never emit a heading with "Tested locally" under it
- Use headings only when a reviewer needs to navigate the pull request: several independent concerns, or a long commit series that no single narrative covers. Reaching for headings on a focused change is the fault the skill names
- One commit: do not restate its message. Say what a reviewer needs beyond it, or reuse the commit body directly
- Keep any `Refs:` trailer or issue reference on its own line at the end

### Relay Contract (for invoking agent)

The wording of the fenced code block is fixed. Relay it under the `delegate-task` relay rules: verbatim, never rewritten.

- Preserve the fencing exactly
- No preamble or trailing commentary unless a follow-up needs it
- When a `make-*` command invoked this drafting step, that command consumes the block as its pull request title and body source; return the block and let the flow continue

### Example

<example_input>
Commits on branch:
- abc123 add user avatar upload endpoint
- def456 add avatar validation and resize
- ghi789 update user profile to display avatar
</example_input>

<example_output>

```
feat(users): add avatar upload and display

Profiles had no way to set an avatar, so every user rendered with the same placeholder. POST /users/avatar now takes an upload, checks the image format, and resizes to one standard dimension before storing it, so the profile page renders a consistent size whatever was sent. Unsupported formats return 415 rather than storing a file the resizer cannot read.

Verified with PNG, JPEG, and WebP uploads, and with a file above the size limit.
```

</example_output>
