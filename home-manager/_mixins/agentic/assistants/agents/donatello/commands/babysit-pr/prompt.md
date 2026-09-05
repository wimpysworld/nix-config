## Babysit PR

Take GitHub PR `$ARGUMENTS` to the finish line: every check green on the current head, every review thread answered, and every required approval given. Fix the CI failures the PR caused, triage flakes, answer reviews, then wait for the humans. Ask for the PR URL only if `$ARGUMENTS` is blank.

Invoke named commands with the provider's prefix. Codex uses `$make-commit`; slash-command runtimes use `/make-commit`. If the platform cannot expand a command, follow that command's prompt directly.

### Authority

Human invocation of this command is the user's consent for: commit, push, `gh-review-reply`, `gh-review-resolve`, `gh run rerun --failed`, `gh pr update-branch` in the one case named under **Triage failures**, `gh pr edit --add-reviewer` to re-request a review, and tracker issue creation and comment.

Forbidden throughout: merge, close, approve, release, force-push, `gh workflow run`, and any change to a PR the user does not own. Never use raw `gh api`; use dedicated subcommands, and `gh-api-safe` for raw reads.

Restate this authority in every sub-agent packet, as `delegate-task` requires.

### Preconditions

Check these before anything else. If one fails, stop and state the reason in one line.

- The working tree is clean.
- The local branch has not diverged from its remote.
- The PR is open and is not a draft.

Classify the repository from `git config user.email` inside it. An address on the `chainguard.dev` domain means work; anything else means personal or community. For a work repository, confirm `$PWD` is under `~/Chainguard/*/` so gitsign applies, and stop if it is not.

### Link the task

Load the `task-tracker` skill. Resolve the linked issues from the Git evidence by its shape rules: `Refs:` trailers on the PR commits, issue-key tokens in the branch name for Linear, and the PR's `closingIssuesReferences` for GitHub. A Linear issue is attached to the PR at start, as its reference describes. A GitHub issue needs nothing here: the `Closes` line in the PR body carries the link, and `finish-pr` moves it after the merge. Record the tracker of the first linked issue, because flake filing below follows it.

### The finish line

Read the state in one call at the start of every shift and after every push:

```sh
gh pr view <url> --json isDraft,state,reviewDecision,mergeStateStatus,statusCheckRollup,reviewRequests,headRefOid
```

The PR is finished when all of these hold on the current head:

- Every required check in `statusCheckRollup` concludes `SUCCESS`, `NEUTRAL`, or `SKIPPED`. An optional check that fails is reported, not fixed.
- No review thread remains after the filter under **Answer reviews**.
- `reviewDecision` is `APPROVED`, or `null` because the branch protection requires no review.

Being behind the base is not a fault. `mergeStateStatus` `BEHIND` with green checks is finished. Never run `gh pr update-branch` to chase the base: work repositories move fast, and a PR that had to stay current would never finish. `DIRTY` is a merge conflict, which is a code decision for the user: report it and stop.

The merge is the user's. Reaching the finish line ends the loop with the report below.

### The loop

Every shift starts with the finish-line read, then a synchronous review scan: fetch the PR's current reviews and review threads through `gh-api-safe`, apply the filter under **Answer reviews**, dispatch `address-code-review` for anything that remains, and wait for it. This scan is an orchestrator action, not a watcher. Never report a head as finished until its scan has completed.

Then dispatch watchers with `delegate-task`, each with fresh context, read-only, and a 30 minute deadline stated in the packet. A watcher stops at the deadline and reports rather than exceeding it, and a watcher that reports "still running" is replaced with a fresh one. Which watchers run depends on what is outstanding:

| Outstanding | Watchers for this shift |
| ----------- | ----------------------- |
| Checks pending or failed | CI watcher and review watcher |
| Checks green, threads or approvals outstanding | Review watcher only |

- **CI watcher**: run `gh pr checks <url> --watch --fail-fast` in bounded calls. Claude Code and Codex cap one tool call at a few minutes, so a 30 minute blocking call is cut: wrap it as `timeout 8m gh pr checks ...`, and when it is cut, read `gh pr checks <url>` once and call again. Never sleep between calls. Return as soon as the checks conclude, with the failed checks named.
- **Review watcher**: poll new reviews, review comments, `reviewDecision`, `reviewRequests`, and the PR `state` through `gh-api-safe` at about 90 second intervals, because GitHub has no watch command for reviews. Return on the first change.

Both watchers return at once when the PR `state` is no longer `OPEN`, so a merged or closed PR ends the loop on the next return even when nobody stops the watchers. Name every watcher and follow-up sub-agent `babysit-pr-<owner>-<repo>-<number>-<role>`, for example `babysit-pr-noughtylinux-development-42-ci`. `finish-pr` run in the same session finds them by that prefix and stops them before it deletes the branch, and the user can do the same by hand.

The orchestrator never sleeps and never polls; it acts when a watcher returns. Watchers never edit files. Dispatch every follow-up to a fresh sub-agent, and serialise everything that touches the working tree so two sub-agents never edit at once.

Budget: 16 shifts or 8 hours, whichever comes first. The loop also ends when the PR merges or closes, when the finish line is reached, or when a `DIRTY` state or a third failure of one check stops it. On the budget, report and end with a `Resume:` line. Re-running is safe because every shift starts from the live PR state.

### Triage failures

When a required check fails and `mergeStateStatus` is `BEHIND`, run `gh pr update-branch` once for that head and watch again before blaming the PR. A stale base produces false attributions. This is the only use of `gh pr update-branch`.

Then sort each failure:

- **Caused by this PR**: the failure traces to code the PR changed.
- **Flaky and unrelated**: infrastructure, a failure that also fails on base, or a check untouched by the diff.

State the evidence for each call.

### Fix what the PR caused

One fresh sub-agent per distinct failure, in parallel where the fixes do not overlap, one error each. Each sub-agent makes the smallest fix, verifies locally where practical, and returns the files changed and why. The orchestrator then runs `make-commit` and pushes with an explicit refspec: `git push origin <branch>`. A bare `git push` depends on tracking configuration that may be absent, and pushes nothing when it is. Never pass `-u`: a sandbox mounts `.git/config` read-only, so the upstream write fails after the push has already landed.

Verify the push landed before you watch, reply, or report the fix. Run `git fetch origin <branch>`, then compare `git rev-parse HEAD` against `git rev-parse FETCH_HEAD`. Report a mismatch and stop. Never trust the exit status alone: a push that matches nothing reports success while doing nothing, so CI never runs and the pull request sits on stale code.

Two fix attempts per distinct check is the limit. Report a third failure; do not fix it again.

### Handle flakes

Run `gh run rerun --failed` once per head SHA. A second flake on the same SHA is not a flake; treat it as caused by the PR.

Then record it in the tracker that **Link the task** resolved. Search first for an open issue naming the same check and comment on it rather than filing a duplicate.

- **Linear, or no linked issue**: file into the flake bucket project. Call `create-project` to find or create it, then `create-task` with the `new` role to file into it. Assign the issue to the user. One project name, used in both workspaces: `Triage and reduce encountered CI flakiness by 50%`. No cycle in the name, and no cycle on the issue. The project is perpetual and reused. The user closes it and creates its replacement on their own schedule, so this command neither knows nor cares about that rollover. Workspace guard: the connected Linear instance is personal when the `WW` team, Wimpy's World, is visible, and work when `FUL`, Fulfillment Automation, is visible. The guard picks the destination, never the project name. File work into the `FUL` team and personal into the `WW` team. If the repository classification and the visible instance disagree, skip the Linear step, report one line saying the profile does not match the repository, and carry on with the rest of the loop.
- **GitHub Project**: run `create-task` against the project the linked issue sits on, so the flake lands as a `Bug` issue in the PR's repository on the same board.

Read `contribution-voice` first unless its complete, current instructions are in this context. Apply it before writing that comment, and name it in the sub-agent packet if a sub-agent writes it. The comment publishes under the user's name. State the check, the evidence that it is flaky, and the head SHA. Nothing else.

### Answer reviews

Thread filter, used by the shift scan and the review watcher alike: skip resolved threads, threads whose most recent reply came from the user, and outdated threads. This is the same filter `address-code-review` applies.

When a review or review comment lands, from a bot or a human, dispatch a fresh sub-agent running `address-code-review` against the PR URL. Give it the same 30 minute deadline as a watcher, and require one progress message when it stops judging and starts fixing. On the deadline it reports the threads answered so far and stops, and the loop dispatches a fresh one.

That command owns the whole cycle. It skips threads already handled, judges each finding, fixes and commits what it accepts, pushes, replies in the thread, and resolves the threads its rules allow. Report what it returns and do nothing further with those threads.

When `reviewDecision` is `CHANGES_REQUESTED` and the fix for that review has been pushed, re-request the review once from that reviewer with `gh pr edit <url> --add-reviewer <login>`. Approvals are given by people. Never approve, never nudge anyone outside GitHub, and never treat a wait for approval as a fault.

### Output

Print a short status line at the end of each shift: head SHA, checks, threads outstanding, `reviewDecision`, shift number. End with a summary:

- Finish line reached, or the reason the loop stopped.
- Every failed check, its group, and the evidence.
- The fixes and the files touched.
- Tracker issues created or commented on.
- Review findings addressed, with threads replied to and resolved.
- Approvals still outstanding, and from whom.
- Anything skipped, with the reason.
- `Resume: /babysit-pr <url>` on slash-command runtimes or `Resume: $babysit-pr <url>` on Codex, only when the loop stopped short of the finish line.

### Constraints

- British English throughout. Short sentences, active voice, no filler.
- Unsigned commits on personal repositories are expected under Fence. They are not an error.
- Never merge, close, approve, force-push, publish a release, or dispatch a workflow.
- Never run `gh pr update-branch` except once per head for a failing check on a behind branch.
- Never use raw `gh api`.
