## PR Done

Wrap up a merged pull request by moving its associated Linear issues to Done. Leave all local Git state and all GitHub state unchanged.

`$ARGUMENTS` is the merged branch name. When it is blank, read the current branch with `git rev-parse --abbrev-ref HEAD`. Stop if the result is `main` or cannot be resolved.

### Authority and side effects

Invoking this command is the user's statement that the pull request merged. Do not try to prove it and never claim that you did.

The only write this command may make is moving an associated Linear issue to Done. Invocation is consent for that status change. Linear reads and those status writes use the network.

Local Git commands are read-only: `git rev-parse --abbrev-ref HEAD`, `git log main..<branch> --format='%(trailers:key=Refs,valueonly)'`, and `git config user.email`. Do not fetch, pull, check out, reset, prune, remove a worktree, delete a local branch, or suggest that the user should do any of those things.

Do not change GitHub state or remote branches. Do not comment on, close, merge, or edit the pull request.

### Process

1. Resolve the branch from `$ARGUMENTS`, or from the current branch when the argument is blank.
2. Collect associated Linear issue keys from exactly two sources:
   - An issue whose `gitBranchName` exactly matches the branch.
   - A `Refs: <ISSUE-KEY>` trailer returned by the read-only `git log` command above.
3. Deduplicate the keys. Never take a key from commit prose, a pull request body, or any other text.
4. Apply the workspace guard below.
5. Handle each associated issue on its own. A failure for one issue must not block the others.
6. Report the branch and each Linear outcome using **Output**. Do not include local clean-up advice.

### Linear transition

Classify the repository from `git config user.email`. An address on the `chainguard.dev` domain means work; anything else means personal. The connected Linear instance is personal when the `WW` team, Wimpy's World, is visible, and work when `FUL` is visible. If the classification and visible instance disagree, skip every transition and report that the profile does not match the repository.

For each associated issue:

- List the team's workflow statuses and select the `completed`-type status named Done. If it does not exist, skip the issue and say so. Never create a status.
- Move forward only. Leave the issue unchanged when its type is already `completed` or `cancelled`.
- Change only its status. Do not comment or change any other field.

Linear failures are not fatal. Do not retry in a loop.

### Output

```markdown
Branch: <branch>
Linear:
- <issue key and its new status, the reason it was skipped, or none>
Local Git: unchanged
GitHub: unchanged
```
