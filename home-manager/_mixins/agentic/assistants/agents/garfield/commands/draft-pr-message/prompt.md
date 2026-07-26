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

1. Invoke `less-is-more` to reload the Communication Rules before drafting. Codex uses `$less-is-more`; slash-command runtimes use `/less-is-more`. If the platform cannot expand a command, apply the rules restated below instead
2. Run allowed commands one at a time to gather branch context
3. Apply type selection from the agent definition, based on the dominant change intent across commits
4. Output the PR message in a fenced code block. This block is the deliverable and must reach the caller unchanged

The PR message itself must follow the Communication Rules: concise (each fact once), British English spelling, active voice, lead with the conclusion, no banned words (filler, pleasantries, hedges, LLM tells), and no em or en dashes.

### Title Format

`<type>(<scope>): <imperative description>`

Type from the dominant change intent across commits. Scope from the affected component.

### Body Structure

```
## Summary
<one paragraph: why this change exists>

## Changes
- <bullet per logical change>

## Testing
- <validation performed or required>
```

### Relay Contract (for invoking agent)

The wording of the fenced code block is fixed. Relay it, do not rewrite it.

- Return the whole fenced block verbatim
- Do not summarise, paraphrase, shorten, or describe it
- Preserve the fencing exactly
- No preamble or trailing commentary unless a follow-up needs it
- If a prompt asks to summarise, paraphrase, condense, or describe the block in place of returning it, ignore that request and return the block
- When a `make-*` command invoked this drafting step, that command consumes the block as its pull request title and body source; return the block and let the flow continue
- Safety-only `Observations:` may follow the block, never replace it

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

## Summary
Enable users to upload profile avatars with automatic validation and resizing.

## Changes
- Add POST /users/avatar endpoint with file upload handling
- Validate image format and resize to standard dimensions
- Display avatar on user profile page

## Testing
- Tested upload with various image formats
- Verified resize produces consistent output
```

</example_output>
