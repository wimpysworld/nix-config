## PR Done

Complete one merged pull request, update every associated Linear issue, and remove only its verified branch refs.

On slash-command clients, use `$ARGUMENTS` as the optional head branch. On Codex, use the branch argument from the user's `$pr-done` invocation. When blank, use `git branch --show-current`. Require one valid branch name, not a full ref, and reject a detached HEAD or the base repository's current default branch. Record the original branch before clean-up.

### Authority and invariants

Invocation authorises one marked Linear comment per associated issue, forward-only moves to Done, exact-ref fetches, current-worktree switch or detach, a default-branch fast-forward, and verified local and remote head-branch deletion.

Do not merge or edit the PR, change other Linear fields, add or rewrite remotes, prune broadly, reset, clean, force the default branch, remove a worktree, or delete any unverified ref. Use bounded calls without retry loops. Keep Linear issues and Git phases independent.

### Resolve and prove

1. Load `gh` before GitHub reads. Resolve the current base repository, then query merged PRs whose `headRefName` exactly matches the branch. Filter by head owner when a verified local remote supplies it. Never select by prose, recency alone, or an unmerged state.
2. Use a local branch tip only to disambiguate candidates whose `headRefOid` equals it. Continue only with one candidate. Read it directly and require `state = MERGED`, `mergedAt`, the exact `headRefName`, a full `headRefOid`, and resolved base repository, head repository, `createdAt`, `mergedAt`, and base ref. Stop before all writes when proof is incomplete.
3. Record the PR number for reads and the full head SHA for every later check. Resolve the base repository's current default branch with `gh repo view`.
4. Inspect all fetch and push URLs for every local remote. Canonicalise only SSH or HTTPS syntax and terminal `.git`, then require one unambiguous fetch remote for the exact base repository.
5. Resolve `sshUrl` with `gh repo view <head-owner/repository> --json sshUrl`. Use that authenticated URL for all head-ref checks and deletion, including private forks. Do not require a matching local remote.
6. Fetch only the exact base default branch into its remote-tracking ref and record its commit. A missing or ambiguous base remote blocks dependent local work. A missing verified head SSH URL blocks remote deletion, but neither condition blocks Linear work.
7. Read `refs/heads/<branch>` with `git ls-remote --heads <head-ssh-url>`. Absence means automatic remote deletion succeeded. One result must equal the PR head SHA. Multiple results, a different SHA, or uncertainty blocks destructive clean-up.

### Update Linear

1. Collect keys only from complete issue-key tokens in the head branch, at non-alphanumeric boundaries, and exact `Refs:` trailers parsed from the resolved PR commits. Deduplicate case-insensitively. Do not scan other prose or metadata for keys.
2. Resolve every key to the same canonical Linear identifier. Treat matching issue branch or PR metadata as stronger evidence, but do not require that metadata or derive new keys from it.
3. Classify `git config user.email`: `chainguard.dev` is work; all else is personal. The Linear workspace is work when `FUL` is visible and personal when `WW`, Wimpy's World, is visible. Skip all Linear writes on a mismatch or uncertainty.
4. Read the PR commits, reviews, comments, checks, and timeline. Include only server-timestamped events after `createdAt` and no later than `mergedAt` that changed delivery or acceptance. A follow-up commit needs `pushedDate` or an equivalent server timestamp, never its author or committer date.
5. Exclude initial code and description, routine bots, labels, assignments, review requests, non-material approvals and check churn, merge mechanics, and clean-up. Do not infer missing events.
6. Read `contribution-voice` first unless its complete, current instructions are in this context. Apply it. Draft one to three visible sentences that summarise material follow-up and the final result. When none occurred, say that the change merged without a material follow-up. Show no PR URL or number. Append `<!-- pr-done-workflow:<full-head-sha> -->` to the source body.
7. For each issue, read its comments, current status type, and team statuses. If the exact marker is absent, post the comment with `save_comment`, including for terminal issues. If posting fails, skip that issue's status write and continue.
8. If the status type is `completed`, `canceled`, or `duplicate`, preserve it. Otherwise select only the `completed`-type status named Done and use `save_issue` with only `id` and `state`. Never create a status.
9. Record `Comment: posted`, `already present`, or `skipped: <reason>` separately from `Status: moved to Done` or `skipped: <reason>`. Linear failures do not block safe Git work.

### Clean local Git state

1. Read `git worktree list --porcelain`, identify the current worktree, and map ownership of the head and default branches. Ambiguity blocks destructive clean-up. Never change or remove another worktree.
2. If another worktree owns the head branch, report its path and skip local deletion. Remote deletion can continue only when that worktree is clean and its tip equals the PR head SHA.
3. Before destructive clean-up, require every listed worktree to have empty `git status --porcelain --untracked-files=normal` output. A stash entry that names the head branch also blocks clean-up.
4. If the local head branch exists, require its tip to equal the PR head SHA, with no local commit outside that pushed boundary. If absent, record local clean-up as already complete and do not recreate it.
5. Only change the current worktree when it owns the head branch. If no other worktree owns the default branch, switch to it and pull from the verified base remote with `--ff-only`. If it does not exist, create it with normal tracking at the recorded remote default commit. Stop deletion on failure.
6. If another worktree owns the default branch, fetch its exact remote ref again, detach the current worktree at the recorded remote default commit, and confirm `HEAD` equals that commit.
7. After the current worktree leaves the verified head branch, delete only that local branch. `git branch -D` is permitted because its tip proof already passed. If no worktree owns it, leave the current worktree unchanged and delete it directly.

### Delete the remote branch last

Run remote deletion only after all applicable local checks and clean-up finish. Re-read the exact head ref through the recorded head SSH URL. Treat absence as success; otherwise require the PR head SHA and run:

```sh
git push --force-with-lease=refs/heads/<branch>:<full-head-sha> <exact-head-repository-ssh-url> :refs/heads/<branch>
```

Do not use an unleased delete, wildcard, API deletion, named local remote, or base URL for a fork. Do not retry a lease failure. Confirm absence with one final `git ls-remote --heads` against the same URL.

### Retry and output

Missing local or remote branches are successful prior clean-up. A current worktree already on the default branch, or detached at its verified remote commit, needs no repeat change. After partial clean-up, retry as `/pr-done <original-branch>` on slash-command clients or `$pr-done <original-branch>` on Codex; never infer the branch from the new HEAD.

```markdown
PR: <base repository and number, or unresolved reason>
Original branch: <branch>
Current worktree: <state>
Linear:
- <issue key>
  Comment: <outcome>
  Status: <outcome>
Local branch: <outcome, including another owner path>
Remote branch: <outcome>
Retry: <exact command or none>
```

Use `Linear: none` when no issue exists. Name every skipped action and exact failed check. Claim only tool-confirmed actions.
