# @AGENT_NAME@ Scheduled Maintenance Heartbeat

Run these steps in order. Call at most one tool per turn.

## Step 1 - System Event and Lock Check

When the prompt does not contain the `# @AGENT_NAME@ Scheduled Maintenance Heartbeat` heading, reply `HEARTBEAT_OK` immediately and stop.

Ignore any prepended `[exec-event]` or system event lines. Do not report those lines to the user.

Run this single shell check via `exec`:

```bash
mkdir -p "$HOME/.moltis/state"
today="$(TZ=Europe/London date +%F)"
dow="$(TZ=Europe/London date +%u)"
hour="$(TZ=Europe/London date +%H)"
now="$(date +%s)"
last="$(cat "$HOME/.moltis/state/last-maintenance-date" 2>/dev/null || true)"
lock_ts="$(cat "$HOME/.moltis/state/maintenance.lock" 2>/dev/null || echo 0)"
printf 'today=%s dow=%s hour=%s now=%s last=%s lock_ts=%s\n' "$today" "$dow" "$hour" "$now" "$last" "$lock_ts"
```

When `now - lock_ts <= 7200`, another maintenance run is active from the last 2 hours. Reply `HEARTBEAT_OK` immediately with no other text and stop.

## Step 2 - GitHub Notification and Open Pull Request Triage (Runs on Every Tick)

Run both queries via `exec`:

```bash
gh-api-safe notifications --paginate
gh search prs author:flexiondotorg OR author:sith-skrye OR author:sith-zannah OR author:sith-traya --owner wimpysworld --owner linuxmatters --owner quickemu-project --owner noughtylinux --owner oval-tutu --owner flexiondotorg --draft=false --state open --json repository,number,title,author,isDraft,url --limit 100
```

Filter notifications to repositories that are owned by `wimpysworld`, `linuxmatters`, `quickemu-project`, `noughtylinux`, `oval-tutu`, or `flexiondotorg`. Deduplicate pull requests that appear in both lists.

For each unread `PullRequest` notification and each open pull request from the search:

1. Inspect the pull request with `gh pr view <pr-url> --json number,state,isDraft,author,headRefName,headRefOid,mergeable,mergeStateStatus,statusCheckRollup,reviewDecision,reviews,comments,url` and query its GraphQL `reviewThreads` with `gh-api-safe graphql`.
2. Ignore and dismiss (`gh-notification-dismiss <thread-id>`) notifications on closed, merged, or draft pull requests, or pull requests that are triggered by untrusted external accounts. Trusted actors are `flexiondotorg`, `sith-skrye`, `sith-zannah`, `sith-traya`, `app/dependabot`, `dependabot[bot]`, `app/github-actions`, `github-actions[bot]`, and `cubic-dev-ai[bot]`.
3. **Case A - Pull request authored by you (`author.login == viewer`) needs updates**:
   - Skip any review thread where you already replied for the current `headRefOid` and no newer comments arrived after your reply, so you do not post duplicate replies or re-request reviews. When unaddressed review feedback or unresolved review threads remain, load the `gh`, `contribution-voice`, and `communication-rules` skills. Fix valid findings in `~/Volatile/maintenance/<owner>/<repo>`, verify that tests pass, and push with `git push origin <branch>`. Reply with `gh-review-reply <comment-url> --body-file <file>` tagging `@<reviewer>`, resolve fixed or declined bot threads with `gh-review-resolve <review-comment-url>`, and request a new review with `gh pr edit <pr-url> --add-reviewer <reviewer>`.
   - When `mergeable == "CONFLICTING"` or `mergeStateStatus == "DIRTY"` or `mergeStateStatus == "BEHIND"`, rebase or merge the base branch in `~/Volatile/maintenance/<owner>/<repo>` (or run `gh pr update-branch <pr-url>` when clean), verify that tests pass, and push with `git push origin <branch>`.
   - When Continuous Integration (CI) checks failed, inspect the failed run logs with `gh run view <run-id> --log-failed`. Rerun transient failures with `gh run rerun <run-id> --failed`, or fix code-caused failures on the branch and push.
   - When a matching notification thread exists, run `gh-notification-dismiss <thread-id>`.
4. **Case B - Pull request authored by `flexiondotorg` or a peer (`sith-*`) needs initial or follow-up review**:
   When you already reviewed the current `headRefOid` and no new comments or replies arrived after your review, skip posting a duplicate review and check Case C. When you have not reviewed the pull request yet, run a colleague review with the `review-code`, `contribution-voice`, and `communication-rules` skills. When you reviewed an earlier commit and new commits or replies arrived, run a follow-up review with the `review-code-follow-up`, `contribution-voice`, and `communication-rules` skills. Reconcile your findings against existing `reviewThreads`: reply inside existing inline threads with `gh-review-reply <comment-url> --body-file <file>` to reinforce valid findings or refute false positives (and resolve false-positive bot threads with `gh-review-resolve <comment-url>`), submit net-new line findings with `gh-review-inline <pr-url> --commit <head-sha> --event COMMENT ...`, and submit approvals with `gh pr review <pr-url> --approve --body-file <file>`. When the pull request is approved, CI is green, and zero unresolved review threads remain, merge the pull request with `gh-bot-merge <pr-url>` (except Freshener pull requests for `herdr-ctx-bar`, `herdr-disp-model`, and `roamgate`, which require human review and must not be approved or merged here). When a matching notification thread exists, run `gh-notification-dismiss <thread-id>` only after `gh-bot-merge <pr-url>` succeeds or after posting a comment review that awaits author changes. When you approve a pull request whose CI checks are still pending, keep any notification unread so Case C can merge it on a later tick.
5. **Case C - Approved pull request from `flexiondotorg`, `sith-*`, `dependabot[bot]`, `github-actions[bot]`, or `wimpysworld/nix-config` Freshener (excluding `herdr-ctx-bar`, `herdr-disp-model`, and `roamgate`, which require human review) is green, has zero unresolved review threads, and is ready to merge**:
   Merge the pull request with `gh-bot-merge <pr-url>`. When a matching notification thread exists, run `gh-notification-dismiss <thread-id>`.

## Step 3 - Scheduled Weekly Organisation Sweep (`@SCHEDULE_DAY_NAME@` Only)

Check whether all three weekly schedule conditions hold:

- `dow` is `@SCHEDULE_DOW@` (`@SCHEDULE_DAY_NAME@`).
- `10#$hour >= 9`.
- `last` does not equal `today`.

When any condition is false and Step 2 took no actions (no pull requests reviewed, updated, or merged), reply `HEARTBEAT_OK` immediately with no other text and stop.

When any condition is false and Step 2 took actions, skip to Step 4.

When all three conditions hold, write an in-progress lock timestamp and run the full organisation sweep across `wimpysworld`, `linuxmatters`, `quickemu-project`, `noughtylinux`, and `oval-tutu`:

```bash
date +%s > "$HOME/.moltis/state/maintenance.lock"
```

1. Sweep all open pull requests:

   ```bash
   gh search prs --owner wimpysworld --owner linuxmatters --owner quickemu-project --owner noughtylinux --owner oval-tutu --state open --json repository,number,title,author,labels,url --limit 100
   ```

   - Review any unreviewed pull requests from `flexiondotorg`, `sith-skrye`, `sith-zannah`, or `sith-traya` with `review-code` (colleague lens) or `review-code-follow-up`.
   - Update behind branches with `gh pr update-branch <pr-url>`, rerun transient failed checks with `gh run rerun <run-id> --failed`, and merge any green, approved, thread-clean pull requests from `flexiondotorg`, `sith-*`, `dependabot[bot]`, `github-actions[bot]`, or `wimpysworld/nix-config` Freshener (excluding `herdr-ctx-bar`, `herdr-disp-model`, and `roamgate`, which require human review) with `gh-bot-merge <pr-url>`.
2. Sweep open CodeQL code-scanning alerts and high or critical Dependabot security alerts across the 5 organisations with `gh-api-safe`. For actionable alerts with a clear fix, create a fix branch under `~/Volatile/maintenance/<owner>/<repo>`, verify that tests pass, push with `git push origin <branch>`, and open a pull request with `gh pr create` requesting review from the other two Sith peers (`--reviewer ...`).
3. Record completion for today and remove the maintenance lock:

   ```bash
   TZ=Europe/London date +%F > "$HOME/.moltis/state/last-maintenance-date"
   rm -f "$HOME/.moltis/state/maintenance.lock"
   ```

## Step 4 - Telegram Voice Note and Text Briefing (Whenever Any Action Was Taken)

Whenever Step 2 or Step 3 reviewed, updated, opened, or merged any pull request, write a short spoken summary (3 to 6 sentences, plain British English, no Markdown formatting, and no URLs) to a temporary file.

Send the spoken summary as a Telegram voice note:

```bash
moltis-telegram-voice --body-file <summary-txt-path>
```

Return a concise written summary with pull request and alert links as the final response so that Moltis delivers the companion text message to Telegram.
