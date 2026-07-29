---
name: review-code
description: "Use when reviewing a pull request, branch, worktree, or commit for defects, or when the user says 'review this PR', 'review my code', 'review this branch', 'code review', or asks to get a change reviewed before it ships. Runs a wide sub-agent fan-out, pressure-tests every blocking finding, and writes a review report."
user-invocable: true
---

# Review Code

Run a substantive review of a change and write a findings report. The caller supplies the review target, the lens, the severity bar, and the report name. This skill supplies the method.

Never mutate GitHub: no comments, approvals, reviews, or merges. Posting is a separate step.

### Input Resolution

Resolve the target to a diff before anything else:

| Input | Reviewed diff |
| --- | --- |
| PR URL or number | `gh pr diff`, and `gh pr view` for description and context |
| Branch name | merge-base with the default branch, to the branch tip |
| The default branch itself | `origin/main..main`, the unpushed commits; if there are none, stop and ask what to review |
| Worktree path | staged and unstaged changes against HEAD |
| Commit SHA | that commit alone |
| No argument | the current worktree's changes |

Use dedicated `gh` subcommands. Raw `gh api` is denied; use `gh-api-safe` for raw API reads.

Record the head commit SHA reviewed. Keep it internal: it is a guard for `post-code-review` and never appears in a review comment.

### Report Location

Write the report to:

```
${TMPDIR:-/tmp}/agent-reviews/<project>/<target>/<review-name>.md
```

Load the `review-report-path` skill and derive `<project>` and `<target>` from it. `<review-name>` is supplied by the calling command.

### Process

1. Invoke `less` to reload the Communication Rules before writing anything. Codex uses `$less`; slash-command runtimes use `/less`. If the platform cannot expand a command, apply the Communication Rules directly.
2. Load the `contribution-voice` skill and follow it when wording findings. The report itself stays private, but `draft-code-review` lifts these findings into a comment posted under the user's name, so they must already read as the user wrote them.
3. Resolve the input to a diff and gather context, per **Input Resolution**.
4. Load the `review-report-path` skill and derive the report path from the resolved target.
5. Fan out to sub-agents, per **Fan-out**.
6. Pressure-test every blocking finding, per **Adversarial pressure-test**.
7. Synthesise one report at the derived path: summary of the change, verification performed, deduplicated findings, conclusion. Drop duplicates raised by more than one agent. Every section except Findings is evidence for the user, never material for a comment, so mark none of it for reuse. Write each finding to the three-sentence budget below, because Findings is the only section `draft-code-review` reads.
8. Relay the report verbatim. Never summarise or paraphrase it. Report the path.

### Fan-out

Delegate to a wide fan-out of sub-agents, in parallel where possible. Divide the review by concern, or by area or file group when the diff is large: for example correctness and logic, security, and tests and behavioural regressions.

Route the security concern to `dibble` sub-agents. Donatello implements; Dibble is the security specialist.

Add a topic sweep: search Linear for related issues and Slack for recent conversations on the same domain, not only what the change links. This builds an understanding of the domain and the recent work around it, so the review learns from prior contributions and does not undo them. Read-only, as ever: no comments or posts.

Each sub-agent's delegation packet must instruct it to:

- Read the surrounding code in the working tree to understand the change in context, within its assigned concern or area.
- Where practical, verify conclusions by building and running the relevant tests on the reviewed code (for example in a temporary worktree), restoring repo state afterwards. Distinguish environmental test failures (also failing on the base branch) from failures the change caused.
- Apply the lens and severity bar the caller set. Do not widen them.
- Load `contribution-voice` and word every finding by it.
- Return findings, each with `file:line` references, severity, and why it matters.
- Say so plainly when its area is clean.
- Never mutate GitHub: no comments, approvals, or merges.

### Adversarial pressure-test

For each finding rated medium or higher that would justify blocking, send a follow-up to the sub-agent that raised it (continue its context): adversarially verify the finding's preconditions against deployment reality. Does the threat or failure mode arise in the deployed configuration? Check the actual runtime context (what executes where, isolation, who can read what, what gets logged or persisted), not just the diff. Downgrade findings whose preconditions do not hold.

This step stops false positives reaching a human. Do not skip it and do not soften it.

### Constraints

- British English throughout. Lead with conclusions. No filler.
- Every sub-agent and the final report must keep feedback succinct and actionable. Name `contribution-voice` in each delegation packet and require it, because a sub-agent runs with fresh context and will not load it otherwise.
- A finding is three sentences at most: the defect, the proof, the fix. One `file:line` reference is the proof; a second instance of the same defect adds nothing. No headings inside a finding, no restating the diff back at the reader, and no paragraph explaining that the surrounding code is correct. A finding that runs to five paragraphs is over budget, whatever its severity.
- The report is the only deliverable. Do not draft a review comment and do not state a verdict; `draft-code-review` owns that.
