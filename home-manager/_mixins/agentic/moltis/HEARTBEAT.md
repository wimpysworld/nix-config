# @AGENT_NAME@ Scheduled Maintenance Heartbeat

Run these steps in order. Call at most one tool per turn.

## 1. Fast Schedule and State Gate (Run First)

If the prompt starts with `[exec-event]` or any system wake event instead of a scheduled timer tick, reply `HEARTBEAT_OK` immediately and stop.

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

Proceed only when all four conditions hold:
- `dow` is `@SCHEDULE_DOW@` (`@SCHEDULE_DAY_NAME@`).
- `10#$hour >= 9`.
- `last` does not equal `today`.
- `now - lock_ts > 7200` (no maintenance run is already in progress from the last 2 hours).

When any condition is false, reply `HEARTBEAT_OK` immediately with no other text and stop.

When all four conditions hold, write an in-progress lock timestamp so overlapping 30-minute ticks do not start a duplicate run while this sweep is active:

```bash
date +%s > "$HOME/.moltis/state/maintenance.lock"
```

## 2. Automated Bot and Freshener Pull Request Sweep

List open Pull Requests (PRs) across `wimpysworld`, `linuxmatters`, `quickemu-project`, `noughtylinux`, and `oval-tutu`:

```bash
gh search prs --owner wimpysworld --owner linuxmatters --owner quickemu-project --owner noughtylinux --owner oval-tutu --state open --json repository,number,title,author,labels,url --limit 100
```

Filter to eligible pull requests only:
- Official Dependabot pull requests where `author.login` is `app/dependabot` or `dependabot[bot]`.
- Official GitHub Actions update pull requests where `author.login` is `app/github-actions` or `github-actions[bot]`.
- Official `wimpysworld/nix-config` Freshener pull requests where `author.login` is `flexiondotorg`, labels include `automated` and `dependencies`, and the title or diff does not touch `herdr-ctx-bar`, `herdr-disp-model`, or `roamgate` (those packages require manual human review).

Never approve or merge pull requests from any other author or from a fork.

For each eligible pull request:
1. Check status with `gh pr view <url> --json mergeable,mergeStateStatus,statusCheckRollup,headRefName,labels`.
2. When `mergeStateStatus` is `"BEHIND"`, update the branch with `gh pr update-branch <url>`.
3. When a check failed because of a transient runner or network error, rerun the failed workflow with `gh run rerun <run-id> --failed`.
4. When all checks pass and the diff is a clean dependency or package update, approve and merge the pull request with `gh-bot-merge <url>`.

## 3. CodeQL and Dependabot Security Alert Triage

Query open CodeQL code-scanning alerts and high or critical Dependabot security alerts across active repositories in `wimpysworld`, `linuxmatters`, `quickemu-project`, `noughtylinux`, and `oval-tutu` with `gh-api-safe`.

When an actionable security alert has a clear, bounded fix:
1. Clone or update the repository under `~/Volatile/maintenance/<owner>/<repo>`.
2. Create a fix branch and apply the minimal fix.
3. Run the repository test suite or build check and verify that it passes.
4. Commit the change, push with `git push origin <branch>`, and open a pull request with `gh pr create`.

## 4. Telegram Voice Note and Text Briefing

Write a short conversational spoken summary (3 to 6 sentences, plain British English, no Markdown formatting, and no URLs) to a temporary file. Cover the merged pull requests, any pull requests blocked by failing Continuous Integration (CI) or awaiting human review (`roamgate`, `herdr-*`), and any security fix pull requests opened.

Send the spoken summary as a Telegram voice note and record completion for today:

```bash
moltis-telegram-voice --body-file <summary-txt-path>
TZ=Europe/London date +%F > "$HOME/.moltis/state/last-maintenance-date"
rm -f "$HOME/.moltis/state/maintenance.lock"
```

Return a concise written summary with pull request and alert links as the final response of the heartbeat turn so Moltis delivers the companion text message to Telegram.
