## Peer Review Pull Request

Run a substantive peer review of GitHub PR `$ARGUMENTS` by delegating to the `donatello` agent. Ask for the PR URL or number if not provided.

### 1. Delegate research

Launch `donatello` with fresh context. The delegation packet must instruct it to:

- Fetch the PR details, description, and full diff with dedicated `gh` subcommands (`gh pr view`, `gh pr diff`). Raw `gh api` is denied; use `gh-api-safe` for raw API reads. Never mutate GitHub: no comments, approvals, or merges.
- Record the head commit SHA reviewed.
- Read the surrounding code in the working tree to understand the change in context.
- Where practical, verify conclusions by building and running the relevant tests on the PR head (e.g. in a temporary worktree), restoring repo state afterwards. Distinguish environmental test failures (also failing on main) from PR-caused failures.
- Review for substance only: correctness bugs, logic errors, security issues, concurrency problems, error-handling gaps, behavioural regressions, missing or wrong tests. Skip nits entirely: no style, naming, formatting, or comment-wording feedback.
- Save findings to `./<PR-number>.md` in the repo root: summary of the change, verification performed, findings (each with file:line references, severity, and why it matters), conclusion. If there are no substantive findings, say so.

### 2. Pressure-test before blocking

For each finding rated medium or higher that would justify "request changes", send a follow-up to the same donatello agent (continue its context): adversarially verify the finding's preconditions against deployment reality. Does the threat or failure mode arise in the deployed configuration? Check the actual runtime context (what executes where, isolation, who can read what, what gets logged or persisted), not just the diff. Downgrade findings whose preconditions do not hold.

### 3. Relay

Relay donatello's report verbatim. Never summarise or paraphrase it.

### 4. Draft review response

Finish with a draft review response in a fenced markdown block that copies cleanly:

- Lead with the verdict: **Approve** ✅ or **Request changes** 🔒
- A short paragraph on what was verified and is sound
- Blocking items (if any), then non-blocking suggestions, each with a concrete suggested fix

### Constraints

- British English throughout. Lead with conclusions. No filler.
