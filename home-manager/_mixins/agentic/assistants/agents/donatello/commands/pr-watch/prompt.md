## PR Watch

Watch GitHub PR `$ARGUMENTS` and shepherd it: fix the CI failures the PR caused, triage flakes, and answer reviews. Ask for the PR URL only if `$ARGUMENTS` is blank.

Invoke named commands with the provider's prefix. Codex uses `$make-commit`; slash-command runtimes use `/make-commit`. If the platform cannot expand a command, follow that command's prompt directly.

### Authority

Human invocation of this command is the user's consent for: commit, push, `gh-review-reply`, `gh-review-resolve`, `gh run rerun --failed`, `gh pr update-branch`, and Linear issue creation and comment.

Forbidden throughout: merge, close, approve, release, force-push, `gh workflow run`, and any change to a PR the user does not own. Never use raw `gh api`; use dedicated subcommands, and `gh-api-safe` for raw reads.

Restate this authority in every sub-agent packet, as `delegate-task` requires.

### Preconditions

Check these before anything else. If one fails, stop and state the reason in one line.

- The working tree is clean.
- The local branch has not diverged from its remote.
- The PR is open.

Classify the repository from `git config user.email` inside it. An address on the `chainguard.dev` domain means work; anything else means personal or community. For a work repository, confirm `$PWD` is under `~/Chainguard/*/` so gitsign applies, and stop if it is not.

### Link Linear

If the branch name or PR body names a Linear issue, attach the PR to that issue at start. Move the issue to Done when the PR merges.

### The watch loop

Before dispatching watchers for the current head SHA, synchronously fetch the PR's current reviews and review threads through `gh-api-safe`. Apply the same thread filter as `address-code-review`: skip resolved threads, threads whose most recent reply came from the user, and outdated threads. Dispatch `address-code-review` for any feedback that remains, then wait for it to finish. This scan is an orchestrator action, not a third watcher or another polling process.

Run this scan before the first 90-second review poller and repeat it after every PR head SHA change, before dispatching watchers for the new head. Never report green or end the loop for a head until its scan has completed.

Dispatch two background watchers with `delegate-task`, each with fresh context and read-only:

- **CI watcher**: `gh pr checks --watch --fail-fast`. It blocks server side, so never sleep or poll around it.
- **Review watcher**: poll new reviews and review comments through `gh-api-safe` at about 90 second intervals. GitHub has no watch command for reviews.

Each watcher stops at a 30 minute deadline and reports rather than exceeding it. The orchestrator never sleeps and never polls; it acts when a watcher returns. Replace a watcher that reports "still running" with a fresh one.

Watchers never edit files. Dispatch every follow-up to a fresh sub-agent, and serialise everything that touches the working tree so two sub-agents never edit at once.

End the loop when the PR merges, the PR closes, checks are green with no unresolved threads, or the 4 hour total budget expires.

### Triage failures

Check whether the branch is behind base before blaming the PR. If it is, run `gh pr update-branch` and watch again; a stale base produces false attributions.

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

Then record it in Linear. Search first for an open issue naming the same check and comment on it rather than filing a duplicate.

Otherwise file it into the flake bucket project. Call `create-project` to find or create that project, then `create-task` with status `Triage` to file into it. Assign the issue to the user.

One project name, used in both workspaces: `Triage and reduce encountered CI flakiness by 50%`. No cycle in the name, and no cycle on the issue. The project is perpetual and reused. The user closes it and creates its replacement on their own schedule, so this command neither knows nor cares about that rollover.

Flakes no longer go to the Linear project whose name matches the repository name. That rule still holds for anything else this command files.

Load the `contribution-voice` skill before writing that comment, and name it in the sub-agent packet if a sub-agent writes it. The comment publishes under the user's name. State the check, the evidence that it is flaky, and the head SHA. Nothing else.

Workspace guard: the connected Linear instance is personal when the `WW` team, Wimpy's World, is visible, and work when `FUL`, Fulfillment Automation, is visible. The guard picks the destination, never the project name. File work into the `FUL` team and personal into the `WW` team. One shared project name is still two projects in two workspaces, so keep this guard. If the repository classification and the visible instance disagree, skip the Linear step, report one line saying the profile does not match the repository, and carry on with the rest of the loop. Never file work into the personal workspace or the reverse.

### Answer reviews

When a review or review comment lands, from a bot or a human, dispatch a fresh sub-agent running `address-code-review` against the PR URL.

Give that sub-agent the same 30 minute deadline as a watcher, and require one progress message when it stops judging and starts fixing. On the deadline it reports the threads answered so far and stops, and the loop dispatches a fresh one.

That command owns the whole cycle. It skips threads already handled, judges each finding, fixes and commits what it accepts, pushes, replies in the thread, and resolves the threads its rules allow. Report what it returns and do nothing further with those threads.

### Output

Print a short status line at the end of each watcher round. End with a summary:

- Every failed check, its group, and the evidence.
- The fixes and the files touched.
- Linear issues created or commented on.
- Review findings addressed, with threads replied to and resolved.
- Anything skipped, with the reason.

### Constraints

- British English throughout. Short sentences, active voice, no filler.
- Unsigned commits on personal repositories are expected under Fence. They are not an error.
- Never merge, close, approve, force-push, publish a release, or dispatch a workflow.
- Never use raw `gh api`.
