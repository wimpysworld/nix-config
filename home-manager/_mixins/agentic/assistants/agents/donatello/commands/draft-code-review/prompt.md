## Draft Code Review

Draft the single GitHub review comment for a review that has already been conducted. This step drafts only; it never posts, approves, or mutates GitHub.

### Input

`$ARGUMENTS` is the review target the report belongs to: a pull request URL or number, a branch, a worktree path, or a commit. Blank means the current worktree.

### House Style

The `contribution-voice` skill governs the structure. These rules are what it does not cover:

- One concise comment, not a list of separate comments
- A changes or comment verdict carries the findings and nothing else. No opening list of what you checked, no verification paragraph, no statement that the rest holds. That is the audit trail; it stays in the report
- Each finding gets three sentences at most: the defect, the proof, the fix
- When approving, say only that. Do not describe what the pull request does; the code speaks for itself
- No praise padding

### Forbidden Commands

These bans govern this drafting step. They do not restrict the command that invoked it.

NEVER execute while drafting:

- `gh pr review` - this step produces the comment, the caller posts it
- `gh pr comment` - this step produces the comment, the caller posts it
- `gh pr merge` - never change pull request state
- `gh pr close` - never change pull request state

### Process

1. Load and follow the `communication-rules` skill before drafting
2. Load the `contribution-voice` skill and follow it. It governs the structure of text published under the user's name
3. Load the `review-report-path` skill and derive `<project>` and `<target>` from `$ARGUMENTS` with it
4. Read the review report from `${TMPDIR:-/tmp}/agent-reviews/<project>/<target>/`. If that directory holds several reports, ask which one to use. If it is missing or empty, list the target directories under `${TMPDIR:-/tmp}/agent-reviews/<project>/` and stop, saying a review must be run first for this target
5. Read the report and decide the verdict from its findings, not from a wish to be agreeable
6. Draft from the report's Findings section only. Its summary, verification, resolved, still-open, and notes sections are evidence that the review happened; none of them reaches the comment. A comment that follows the report's section order is a compression of the report, which is the failure
7. State the verdict on one line, then output the comment in one fenced markdown block. This block is the deliverable and must reach the caller unchanged

The comment itself must follow the Communication Rules: concise (each fact once), British English spelling, active voice, lead with the conclusion, no banned words (filler, pleasantries, hedges, LLM tells), and no em or en dashes.

### Verdict Selection

- **Approve** when no finding blocks
- **Changes** when at least one finding would make the change wrong, unsafe, or incomplete
- **Comment** when there is something worth saying but nothing blocking and no approval is warranted

### Relay Contract (for invoking agent)

The wording of the fenced code block is fixed. Relay it under the `delegate-task` relay rules: verbatim, never rewritten.

- Preserve the fencing exactly
- No preamble or trailing commentary beyond the verdict line
- When `post-code-review` invoked this drafting step, that command consumes the block as its comment source; return the block and let the flow continue

### Example

<example_input>
Report finds a race on the shared cache map and an unbounded retry loop.
</example_input>

<example_output>

Verdict: changes

```markdown
`cache.Set` writes the shared map without holding `mu`. Take the same lock `cache.Get` uses, or swap to `sync.Map`.

`fetchWithRetry` retries forever on a 4xx. Cap the attempts and return the last error for any non-retryable status.
```

</example_output>

The example opens on the first finding. It names no count, states nothing about what was checked, and says nothing about the parts that are correct.
