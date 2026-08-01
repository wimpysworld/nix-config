## PR Is Merged

The user says the pull request they have been working on is merged. Return the repository to a clean state: `main` checked out and up to date, the merged branch gone, and any worktree for it removed. Then move any associated Linear issue to Done.

`$ARGUMENTS` is the merged branch name. When it is blank, use the current branch.

### The merge is asserted, not proven

Invoking this command is the user's statement that the pull request merged. This command works from local Git only, so it cannot verify that statement. Never claim it did.

That puts the whole weight on the safety checks in step 6. They are all that stands between the user's assertion and work that cannot be recovered. Run every one of them before deleting anything. When any of them finds something, stop, report exactly what was found and where, and delete nothing. The user can deal with it and run the command again.

### Authority

This command deletes a local branch, removes worktrees, and writes to Linear. Treat explicit human invocation as consent to fetch, to check out and fast-forward `main`, to remove the merged branch's worktrees, to delete the merged local branch, and to move the associated Linear issues to Done. Nothing else: no force flags on a worktree removal, no `git push` of any kind, no merging, no closing, no change to any other branch, and in Linear no comment, no other field change, and no other issue.

Out of scope: this command changes no GitHub state, and reads no pull request. For Git and GitHub it works from local Git only.

### Process

Run each command separately. Do not chain commands with `&&`, `;`, or `|`.

1. Resolve the branch. Use `$ARGUMENTS` when given, otherwise `git rev-parse --abbrev-ref HEAD`. Stop if it is `main`.
2. Find the upstream with `git rev-parse --abbrev-ref --symbolic-full-name <branch>@{u}`. If the branch has no upstream, stop: nothing was ever pushed, so nothing can have merged.
3. Record the upstream's current commit with `git rev-parse <upstream>`. Do this before the fetch, because a prune can delete the remote-tracking ref and take the commit with it.
4. Run `git fetch --prune`.
5. Corroborate, and never block on the result. Check the remote-tracking ref with `git rev-parse --verify --quiet <upstream>`. A ref the prune removed means the remote branch is gone, which is what GitHub does on merge when the repository is set up that way, and is good corroboration. A ref that survives means either the repository keeps merged branches, which is normal, or the branch did not merge. Report which case it was. When the ref survives, use its commit in step 6; when it is gone, use the commit recorded in step 3.
6. Check for work that would be lost. Run all of these before deleting anything.
   - Find every worktree for the branch with `git worktree list --porcelain`. A branch may have more than one. Check each, handle each, and report each.
   - In each of those worktrees, run `git -C <worktree-path> status --porcelain --untracked-files=normal`. Any output means uncommitted changes, staged changes, or untracked files that are not ignored.
   - Run `git stash list`. An entry naming the merged branch counts. Ignore entries for other branches.
   - List commits that never reached the upstream with `git log <upstream-commit>..<branch> --oneline`. This check matters most. A commit that was never pushed was never in the pull request, so it cannot have merged, and deleting the branch destroys it.
   - If any check finds something, stop, report exactly what and in which worktree, and delete nothing.
7. Collect the Linear issue keys, following **Linear transition** below. Do it here, while the branch still exists: read the branch name, and read the trailers with `git log main..<branch> --format='%(trailers:key=Refs,valueonly)'`. Record the keys now, because step 11 deletes the branch and takes the trailers with it. Write nothing to Linear yet.
8. Move to the main worktree, whose path is the first entry in `git worktree list`. Run every remaining Git command as `git -C <main-worktree-path> ...`. A worktree cannot be removed while it is the current directory, and the current directory may be the worktree about to go.
9. Update `main`. Check it out with `git -C <main-worktree-path> checkout main`, then run `git -C <main-worktree-path> pull --ff-only`. If either is refused, stop and report it. A diverged `main` is the user's call to resolve, not this command's.
10. Remove each worktree with `git -C <main-worktree-path> worktree remove <worktree-path>`, then run `git -C <main-worktree-path> worktree prune`. Never pass `--force`. If a removal is refused, step 6 missed something: stop and report it rather than forcing.
11. Delete the local branch with `git -C <main-worktree-path> branch -D <branch>`. `git branch -d` refuses a squash-merged branch, because its commits never appear on `main` as themselves, and a squash merge is the normal case here. What makes `-D` safe here is the user's assertion plus the checks in step 6, not any lookup. Never reach for it on a branch that failed a check.
12. Move each issue collected in step 7 to Done, following **Linear transition** below. Do it here, after the local cleanup has succeeded, so a Linear problem cannot leave the repository half-tidied. A Linear failure never stops this command and never undoes anything above.
13. Report, following **Output** below. Carry the step 5 result and each step 12 outcome into the report, and say if the user's shell is still sitting in a worktree that was removed.
14. If the remote-tracking ref survived the prune in step 5, print the notice from **Dangling remote branch** below as the last thing you say. If the prune removed it, say nothing beyond the corroboration line already in the report: no notice, no empty section, no "nothing to do here".

Never reset, delete, or force anything on `main` itself, and never delete a branch other than the one named in step 1. Never run `git push`, and never delete the remote branch: that is a destructive push and needs the user's own say-so.

The `git push origin --delete` line in step 14 is printed for the user to run, never run by this command. Keep it that way. Never offer a `gh` form of it either: the GitHub CLI has no branch-delete subcommand, and the raw API route is denied.

### Linear transition

Two things associate an issue, and nothing else does: the branch name, when the branch came from Linear's `gitBranchName`, and a `Refs: <ISSUE-KEY>` trailer on any commit in the branch. Never take a key from prose. A key mentioned in prose is not an association.

Workspace guard: classify the repository from `git config user.email`. An address on the `chainguard.dev` domain means work; anything else means personal. The connected Linear instance is personal when the `WW` team, Wimpy's World, is visible, and work when `FUL` is visible. If the classification and the visible instance disagree, skip the transition and report one line saying the profile does not match the repository. Never touch a work issue from the personal workspace or the reverse.

Handle each associated issue on its own, and report each one. A branch may carry more than one `Refs:` trailer.

- Match the status by name. List the team's workflow statuses and take the `completed`-type status named Done. If the team has no `completed`-type status by that name, skip the issue and say so. Never invent a status and never create one.
- Move forward only. Leave the issue where it is when its type is already `completed`, and when its type is `cancelled`, which covers Cancelled and Duplicate. A merge must never bring a deliberately cancelled issue back as Done.

Never fatal. The local cleanup is the deliverable: `main` fast-forwarded, the worktrees removed, the branch deleted. If Linear is unreachable, a key does not resolve, the team has no Done status, or the write fails, report it in one line and finish successfully. Never block, never retry in a loop, and never undo any local change because of a Linear failure.

### Dangling remote branch

Only when the remote-tracking ref survived the prune. Fill in the branch name so the command copies and runs as it stands, never leave a placeholder. Put it after the report, on its own, as the last thing in the response:

````markdown
**The remote branch `<branch>` is still on origin.**

GitHub did not delete it on merge. Deleting a remote branch is a destructive push, so it is yours to run:

```sh
git push origin --delete <branch>
```
````

### Output

A clean finish is the report on its own:

```markdown
Branch: <branch>
Remote branch: gone, which corroborates the merge
main: <short sha>, <commits pulled, or already up to date>
Worktrees removed:
- <path, or none>
Branch deleted: <branch>
Linear:
- <issue key and its new status, the reason it was skipped, or none>
Left for you:
- <removed working directory, or none>
```

A finish with a surviving remote branch is the report and the notice after it:

`````markdown
Branch: <branch>
Remote branch: still present on origin
main: <short sha>, <commits pulled, or already up to date>
Worktrees removed:
- <path, or none>
Branch deleted: <branch>
Linear:
- <issue key and its new status, the reason it was skipped, or none>
Left for you:
- the remote branch `<branch>`

**The remote branch `<branch>` is still on origin.**

GitHub did not delete it on merge. Deleting a remote branch is a destructive push, so it is yours to run:

```sh
git push origin --delete <branch>
```
`````
