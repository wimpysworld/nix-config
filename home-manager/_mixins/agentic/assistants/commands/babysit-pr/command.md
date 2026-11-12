## Babysit PR

Watch GitHub PR `$ARGUMENTS` until a live read verifies merge or the run exhausts 16 shifts or eight hours, whichever comes first. Fix the CI failures the PR caused, triage flakes, answer reviews, then keep watching for merge. Readiness is not completion. Ask for the PR URL only if `$ARGUMENTS` is blank.

Resolve named workflows through the available skill catalogue, configured skill roots, or repository command source. Read their bodies before use. Supply exact arguments, this command's authority, and the return contract. Follow `make-commit` and its direct draft phase in this context without generated launch wrappers. The coordinator owns every specialist dispatch for this command. Workers return directly and launch no agents.

### Authority

Human invocation, or an authorised `make-pr` handoff under its completion policy, supplies consent for: commit, push, `gh-review-reply`, `gh-review-resolve`, `gh-review-unresolve`, `gh run rerun --failed`, `gh pr update-branch` in the one case named under **Triage failures**, `gh pr edit --add-reviewer` to re-request a review, and tracker issue creation and comment. A nested handoff must supply the exact PR URL, classification evidence, and this bounded authority. A command name or a maintenance read supplies no authority. Honour user opt-outs and later stops.

Forbidden throughout: merge, close, approve, release, force-push, `gh workflow run`, and any change to a PR the user does not own. Never use raw `gh api`; use dedicated subcommands, and `gh-api-safe` for raw reads.

Restate this authority in every worker packet, as `delegate-task` requires.

### Preconditions

Check these before anything else. If one fails, report `blocked`, not successful completion, and state the reason.

- The working tree is clean.
- The local branch has not diverged from its remote.
- The PR is open and is not a draft.
- The authenticated user owns the PR. Fetch the author, head repository and owner, head branch and SHA, base branch, URL, state, and draft status. Match these against the intended PR, local branch, origin, and checked-out commit. Use `gh-api-safe user --jq .login` for the authenticated login. Stop on a mismatch before any mutation. Never mark a draft ready to pass this check.

Resolve and read `make-pr`'s **Repository classification** section as policy only. Do not execute its creation workflow. Use the verified PR's base repository and any explicit user classification. Resolve the body from the configured runtime root: Codex's `skills/make-pr/SKILL.md`, Claude Code or OpenCode's `commands/make-pr.md`, or Pi's `prompts/make-pr.md`. Codex follows `home.preferXdgDirectories`. Repository source fallback is `commands/make-pr/command.md` under the shared assistants directory. Stop if the policy cannot be read. Do not copy its allowlist here.

Keep signing checks separate from ownership. When classification is `work` or `git config user.email` is on `chainguard.dev`, require `$PWD` under `~/Chainguard/*/` so gitsign applies. Stop otherwise. An email address alone never grants automatic handoff eligibility. For an unknown classification, skip Linear writes until the destination workspace is established.

### Link the task

Load the `task-tracker` skill. Resolve the linked issues from the Git evidence by its shape rules: `Refs:` trailers on the PR commits, issue-key tokens in the branch name for Linear, and the PR's `closingIssuesReferences` for GitHub. A Linear issue is attached to the PR at start, as its reference describes. A GitHub issue needs nothing here: the `Closes` line in the PR body carries the link, and `finish-pr` moves it after the merge. Record the tracker of the first linked issue, because flake filing below follows it.

### Readiness and completion

Read the state in one call at the start of every shift and after every push:

```sh
gh pr view <url> --json isDraft,state,reviewDecision,mergeStateStatus,statusCheckRollup,reviewRequests,headRefOid
```

The PR is ready when all of these hold on the current head:

- Every required check in `statusCheckRollup` concludes `SUCCESS`, `NEUTRAL`, or `SKIPPED`. An optional check that fails is reported, not fixed.
- No review thread remains after the filter under **Answer reviews**. Check unresolved threads and newer substantive reviewer findings in resolved threads before reporting readiness.
- `reviewDecision` is `APPROVED`, or `null` because the branch protection requires no review.

Being behind the base is not a fault. `mergeStateStatus` `BEHIND` with green checks does not end the run. Never run `gh pr update-branch` to chase the base. `DIRTY` is a merge conflict for the user: report `blocked` and stop.

The merge is the user's. When ready, report `ready-awaiting-merge` and keep watching. Only a live `state: MERGED` read verifies merge. A closed, unmerged PR is `cancelled`, not successful completion. Do not infer merge from checks, approvals, watcher exit status, or readiness.

### The loop

Create one run record before preconditions: start time, absolute eight-hour deadline, and zero shifts started. Preserve per-check fix attempts, per-head reruns and branch updates, and review re-requests throughout the run. Never recursively invoke this command or renew its budget after a fix.

At shift entry, check the deadline and shift limit, then increment shifts started exactly once. Idle shifts count. Each shift starts with the live PR read above, then a synchronous review scan. Fetch current reviews and threads through `gh-api-safe`. Apply **Answer reviews** and complete its single-pass phase if findings remain. That phase returns to **Next shift**, not to a final response. Count the phase as part of this shift, not each inner fix, commit, push, or reply.

Set every watch and review phase deadline to the earlier of 30 minutes from phase start and the run deadline. Bound other phases, worker packets, and tool waits by the remaining run time too. Check time before each dispatch or mutation and after every return. At the deadline, start no further work. Collect completed results and checkpoint unfinished work without discarding edits.

If required checks have failed, complete the applicable triage and correction phase, then return through **Next shift**. Otherwise, dispatch fresh, read-only watchers through `delegate-task` with their absolute phase and run deadlines. A watcher stops at its deadline and reports. Replace a watcher only when a native notification or blocking watch can continue the wait. Never reset the cumulative 30 second sleep-polling budget. Which watchers run depends on what is outstanding:

| Outstanding | Watchers for this shift |
| ----------- | ----------------------- |
| Checks pending | CI watcher and review/state watcher |
| Checks green, threads or approvals outstanding | Review/state watcher only |
| Ready, awaiting merge | Review/state watcher only |

- **CI watcher**: run `gh pr checks <url> --watch --fail-fast` in bounded calls. Cap each call at eight minutes or the remaining phase time, whichever is shorter. After a tool timeout, read checks once and continue only while checks remain pending and time remains. Never sleep between calls. Return as soon as checks conclude, with failed checks named.
- **Review/state watcher**: use an available `gh-pr-watch <url> --state-dir <new-private-directory> --timeout <remaining-seconds>` in a PTY. Bound its timeout by the phase and run deadlines. It watches reviews, approvals, state, head, and aggregate check changes through native `watch`. Keep the same process across tool yields, retain its session identifier, and use native waits. The helper seeds a baseline and refreshes after return. Read its final JSON or `result.json`: exit 0 means changed, 124 means deadline, 1 means error, and 130 means interrupted. None proves merge. Treat errors as blocked, not unchanged. Refresh live state before acting on any return.

If `gh-pr-watch` or PTY support is unavailable, use another verified native notification or blocking facility with the same coverage. Otherwise, read reviews, review comments, `reviewDecision`, `reviewRequests`, PR state, and head once through `gh-api-safe`. Return `capability-blocked` when unchanged. A one-shot read is not a watch. Never invent a helper or move a sleep-polling loop into one. Source configuration alone does not prove that the helper is installed.

Bind each watcher to the verified head SHA. On every return, refresh PR state and head before using its result. Stop obsolete watches and discard results for an older head. A CI watch alone does not establish continuous review or merge coverage. Name every watcher and follow-up worker `babysit-pr-<owner>-<repo>-<number>-<role>`, for example `babysit-pr-noughtylinux-development-42-ci`. `finish-pr` finds this prefix and stops workers before deleting the branch.

The coordinator never sleeps and never polls. It acts on watcher returns, phase completion, or deadlines. Watchers never edit files. Dispatch follow-up fixes to fresh workers and serialise working-tree changes. If monitoring is unavailable, finish bounded actionable work, then checkpoint `capability-blocked`. Do not repeatedly dispatch one-shot readers or consume idle shifts to simulate waiting. State that no background monitoring continues.

### Next shift

Every corrective phase returns here: CI fixes, review fixes and replies, flake reruns, permitted branch updates, and review re-requests. A watcher event or an idle watch deadline returns here too. Verify every push, then refresh the live PR head and state. Discard stale watches before continuing. Preserve all attempt counters.

Close the current shift with its status line. If merged, report `merged`. Otherwise, if 16 shifts have started or the run deadline arrives, report `budget-exhausted` unless a final live read verifies merge. Bound that read by the remaining run time and reserve time before the eight-hour deadline. If no time remains, use the last verified snapshot and state its time. A correction during shift 16 never starts shift 17. When budget remains, start the next shift automatically without another permission question or command invocation.

User stop and closed-unmerged state are `cancelled`. Safety, authority, identity, signing, push verification, conflicts, repair limits, and unavailable monitoring are `blocked` exceptions. Report their reason, not readiness as success. Stop owned watches on terminal exit. On interruption, record PR identity, start/deadline/elapsed time, shifts started, current phase and head, all counters, and watcher identifiers with their actual status. Resume from that checkpoint and live state without resetting the budget or counting the interrupted shift twice. Exhaustion requires an explicitly requested new run, not automatic renewal.

### Triage failures

When a required check fails and `mergeStateStatus` is `BEHIND`, run `gh pr update-branch` once for that head. Return through **Next shift** and watch the refreshed head before blaming the PR. A stale base produces false attributions. This is the only use of `gh pr update-branch`.

Then sort each failure:

- **Caused by this PR**: the failure traces to code the PR changed.
- **Flaky and unrelated**: infrastructure, a failure that also fails on base, or a check untouched by the diff.

State the evidence for each call.

### Fix what the PR caused

Dispatch one fresh fix worker per distinct failure, one error each. Run fix workers serially, even when their fixes do not overlap. Read-only watchers can run in parallel. Each worker makes the smallest fix, verifies locally where practical, and returns the files changed and why. The coordinator then follows the loaded `make-commit` body and pushes with an explicit refspec: `git push origin <branch>`. A bare `git push` depends on tracking configuration that may be absent, and pushes nothing when it is. Never pass `-u`: a sandbox mounts `.git/config` read-only, so the upstream write fails after the push has already landed.

Verify the push landed before you watch, reply, or report the fix. Run `git fetch origin <branch>`, then compare `git rev-parse HEAD` against `git rev-parse FETCH_HEAD`. Report a mismatch and stop. Never trust the exit status alone: a push that matches nothing reports success while doing nothing, so CI never runs and the pull request sits on stale code.

Two fix attempts per distinct check is the limit. Report a third failure; do not fix it again.

### Handle flakes

Run `gh run rerun --failed` once per head SHA. A second flake on the same SHA is not a flake; treat it as caused by the PR.

Then record it in the tracker that **Link the task** resolved. Search first for an open issue naming the same check and comment on it rather than filing a duplicate.

- **Linear, or no linked issue**: find the existing flake bucket project, then follow `create-task` with the `new` role to file into it. Do not create a project. If none exists, report the missing project and continue without filing. Apply the Linear reference's creation-assignee policy. One project name, used in both workspaces: `Triage and reduce encountered CI flakiness by 50%`. No cycle in the name, and no cycle on the issue. The project is perpetual and reused. The user closes it and creates its replacement on their own schedule, so this command neither knows nor cares about that rollover. Workspace guard: the connected Linear instance is personal when the `WW` team, Wimpy's World, is visible, and work when `FUL`, Fulfillment Automation, is visible. The guard picks the destination, never the project name. File work into the `FUL` team and personal into the `WW` team. If the repository classification is unknown or the visible instance disagrees, skip the Linear step, report the missing or mismatched classification, and carry on with the rest of the loop.
- **GitHub Project**: run `create-task` against the project the linked issue sits on, so the flake lands as a `Bug` issue in the PR's repository on the same board.

Read `contribution-voice` first unless its complete, current instructions are in this context. Apply it before writing that comment, and name it in the worker packet if a worker writes it. The comment publishes under the user's name. State the check, the evidence that it is flaky, and the head SHA. Nothing else.

### Answer reviews

Thread filter, used by the shift scan and the review watcher alike: skip resolved threads (`isResolved: true`) unless the most recent comment is a substantive finding from a reviewer after the comment that resolved or refuted the thread, skip threads whose most recent reply came from the user, and skip outdated threads. When a resolved thread carries a newer substantive reviewer finding, run `gh-review-unresolve <review-comment-url>` on it, judge it, and address it like any other open thread. This is the same filter `address-code-review` applies.

When a review or review comment lands, follow the `address-code-review` body here with the exact PR URL. Ignore its generated launch wrapper. Keep orchestration, staging, commits, push, and replies in this context. Apply the earlier of its 30 minute phase deadline and the run deadline. Only this coordinator dispatches finding workers, with that deadline and no delegation. Report progress when judging ends and fixing starts. On completion or deadline, collect completed work and report the threads answered. Re-request reviews as allowed below, then return through **Next shift**. Resume outstanding threads from live state while budget remains.

That workflow owns the review cycle within this command. It skips handled threads, judges each finding, dispatches fixes, commits, pushes, replies, and resolves threads as its rules allow. Report its result and do nothing further with those threads.

When `reviewDecision` is `CHANGES_REQUESTED` and the fix for that review has been pushed, re-request the review once from that reviewer with `gh pr edit <url> --add-reviewer <login>`. Approvals are given by people. Never approve, never nudge anyone outside GitHub, and never treat a wait for approval as a fault.

### Output

Print a short status line at the end of each shift: head SHA, checks, threads outstanding, `reviewDecision`, shift number. End with a summary:

- `merged`, `budget-exhausted`, `blocked`, or `cancelled`, with the verified reason and latest readiness state.
- Every failed check, its group, and the evidence.
- The fixes and the files touched.
- Tracker issues created or commented on.
- Review findings addressed, with threads replied to and resolved.
- Approvals still outstanding, and from whom.
- Anything skipped, with the reason.
- For blocked or interrupted runs, include the checkpoint and `Resume: /babysit-pr <url>` or `Resume: $babysit-pr <url>` on Codex. Require that checkpoint on resume. For exhausted runs, label any follow-up as a new run requiring an explicit request. Do not print a resume action after merge or user cancellation.

### Constraints

- British English throughout. Short sentences, active voice, no filler.
- Unsigned commits on personal repositories are expected under Fence. They are not an error.
- Never merge, close, approve, force-push, publish a release, or dispatch a workflow.
- Never run `gh pr update-branch` except once per head for a failing check on a behind branch.
- Never use raw `gh api`.
