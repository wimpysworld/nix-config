## Peer Review Pull Request

Run a substantive peer review of GitHub PR `$ARGUMENTS`. Ask for the PR URL or number if not provided.

### 1. Delegate research

Fetch the PR details, description, and full diff first with dedicated `gh` subcommands (`gh pr view`, `gh pr diff`). Raw `gh api` is denied; use `gh-api-safe` for raw API reads. Record the head commit SHA reviewed. Never mutate GitHub: no comments, approvals, or merges.

Delegate to a wide fan-out of sub-agents, in parallel where possible. Divide the review by concern, or by area or file group when the diff is large: for example correctness and logic, security, and tests and behavioural regressions. Each sub-agent's delegation packet must instruct it to:

- Read the surrounding code in the working tree to understand the change in context, within its assigned concern or area.
- Where practical, verify conclusions by building and running the relevant tests on the PR head (e.g. in a temporary worktree), restoring repo state afterwards. Distinguish environmental test failures (also failing on main) from PR-caused failures.
- Review for substance only: correctness bugs, logic errors, security issues, concurrency problems, error-handling gaps, behavioural regressions, missing or wrong tests. Skip nits entirely: no style, naming, formatting, or comment-wording feedback.
- Return findings, each with file:line references, severity, and why it matters. If there are no substantive findings in its area, say so.
- Never mutate GitHub: no comments, approvals, or merges.

Synthesise the team's findings into one report at `./<PR-number>.md` in the repo root: summary of the change, verification performed, deduplicated findings, conclusion. Drop duplicates raised by more than one agent.

### 2. Pressure-test before blocking

For each finding rated medium or higher that would justify "request changes", send a follow-up to the sub-agent that raised it (continue its context): adversarially verify the finding's preconditions against deployment reality. Does the threat or failure mode arise in the deployed configuration? Check the actual runtime context (what executes where, isolation, who can read what, what gets logged or persisted), not just the diff. Downgrade findings whose preconditions do not hold.

### 3. Relay

Relay the synthesised report verbatim. Never summarise or paraphrase it.

### 4. Draft review response

Finish with a draft review response in a fenced markdown block that copies cleanly:

- Lead with the verdict: **Approve** ✅ or **Request changes** 🔒
- A short paragraph on what was verified and is sound
- Blocking items (if any), then non-blocking suggestions, each with a concrete suggested fix

### Constraints

- British English throughout. Lead with conclusions. No filler.
- Every sub-agent and the final report must keep feedback succinct and actionable:
  - Lead with the conclusion, then the reasoning.
  - Use the fewest sentences that fully answer; state each fact once.
  - Use active voice, short common words, and British English spelling.
  - No filler, pleasantries, hedges, or waffle.
