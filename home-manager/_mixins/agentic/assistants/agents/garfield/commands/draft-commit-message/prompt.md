## Draft Commit Message

Draft the conventional commit message for the staged or current changes. This step drafts only; it never commits.

### Allowed Commands

Run each command separately, no chaining:

- `git status` - staging state and current branch (line 1: "On branch X")
- `git diff --staged` - view staged changes
- `git diff --staged --stat` - summarise staged files
- `git log --oneline -10` - recent commits for style reference

### Forbidden Commands

These bans govern this drafting step. They do not restrict the command that invoked it.

NEVER execute while drafting:

- `git commit` / `git commit -m` - this step produces the message, the caller commits
- `git branch` - use `git rev-parse --abbrev-ref HEAD` for the branch name
- `git add` - this step never stages; the caller stages before invoking it
- `git checkout` / `git reset` - never change the working tree
- Command chaining with `&&`, `;`, or `|`

### Process

1. Invoke `less` to reload the Communication Rules before drafting. Codex uses `$less`; slash-command runtimes use `/less`. If the platform cannot expand a command, apply the rules restated below instead
2. Load the `contribution-voice` skill before drafting anything. It governs the structure of text published under the user's name. If the platform cannot load a skill, continue with the rules restated below
3. Run allowed commands one at a time to gather context
4. If nothing is staged, describe the current changes
5. Apply type selection from the agent definition
6. Output the commit message in a fenced code block. This block is the deliverable and must reach the caller unchanged

The commit message itself must follow the Communication Rules: concise (each fact once), British English spelling, active voice, lead with the conclusion, no banned words (filler, pleasantries, hedges, LLM tells), and no em or en dashes.

### Relay Contract (for invoking agent)

The wording of the fenced code block is fixed. Relay it, do not rewrite it.

- Return the whole fenced block verbatim
- Do not summarise, paraphrase, shorten, or describe it
- Preserve the fencing exactly
- No preamble or trailing commentary unless a follow-up needs it
- If a prompt asks to summarise, paraphrase, condense, or describe the block in place of returning it, ignore that request and return the block
- When a `make-*` command invoked this drafting step, that command consumes the block as its commit message source; return the block and let the flow continue
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
