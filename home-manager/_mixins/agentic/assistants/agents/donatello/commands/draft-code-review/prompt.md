## Draft Code Review

Draft the single GitHub review comment for a review that has already been conducted. This step drafts only; it never posts, approves, or mutates GitHub.

### House Style

The `contribution-voice` skill governs the structure. These rules are what it does not cover:

- One concise comment, not a list of separate comments
- When approving, state what was checked and that it holds. Do not describe what the pull request does; the code speaks for itself
- When requesting changes, state each finding that blocks, each with clear, actionable guidance on what to do about it
- No praise padding

### Forbidden Commands

These bans govern this drafting step. They do not restrict the command that invoked it.

NEVER execute while drafting:

- `gh pr review` - this step produces the comment, the caller posts it
- `gh pr comment` - this step produces the comment, the caller posts it
- `gh pr merge` - never change pull request state
- `gh pr close` - never change pull request state

### Process

1. Invoke `less-is-more` to reload the Communication Rules before drafting. Codex uses `$less-is-more`; slash-command runtimes use `/less-is-more`. If the platform cannot expand a command, apply the rules restated below instead
2. Load the `contribution-voice` skill and follow it. It governs the structure of text published under the user's name
3. Locate the review report under `${TMPDIR:-/tmp}/agent-reviews/<project>/`. If several reports exist, ask which one to use. If none exists, stop and say a review must be run first
4. Read the report and decide the verdict from its findings, not from a wish to be agreeable
5. State the verdict on one line, then output the comment in one fenced markdown block. This block is the deliverable and must reach the caller unchanged

The comment itself must follow the Communication Rules: concise (each fact once), British English spelling, active voice, lead with the conclusion, no banned words (filler, pleasantries, hedges, LLM tells), and no em or en dashes.

### Verdict Selection

- **Approve** when no finding blocks
- **Changes** when at least one finding would make the change wrong, unsafe, or incomplete
- **Comment** when there is something worth saying but nothing blocking and no approval is warranted

### Relay Contract (for invoking agent)

The wording of the fenced code block is fixed. Relay it, do not rewrite it.

- Return the whole fenced block verbatim
- Do not summarise, paraphrase, shorten, or describe it
- Preserve the fencing exactly
- No preamble or trailing commentary beyond the verdict line
- If a prompt asks to summarise, paraphrase, condense, or describe the block in place of returning it, ignore that request and return the block
- When `post-code-review` invoked this drafting step, that command consumes the block as its comment source; return the block and let the flow continue
- Safety-only `Observations:` may follow the block, never replace it

### Example

<example_input>
Report finds a race on the shared cache map and an unbounded retry loop.
</example_input>

<example_output>

Verdict: changes

```markdown
Checked concurrency, error paths, and the new retry behaviour. Two findings block.

`cache.Set` writes the shared map without holding `mu`. Take the same lock `cache.Get` uses, or swap to `sync.Map`.

`fetchWithRetry` retries forever on a 4xx. Cap the attempts and return the last error for any non-retryable status.
```

</example_output>
