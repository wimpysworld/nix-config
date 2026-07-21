## Make PR

Draft the pull request title and body with `draft-pr-message`, then create a pull request for the current branch.

This command mutates remote Git and GitHub state by pushing only when needed and running `gh pr create`. Treat explicit human invocation of this command as consent for those actions. Never use raw `gh api`.

Command invocation: use the current provider's command prefix when invoking `draft-pr-message`. Codex uses `$draft-pr-message`; slash-command runtimes use `/draft-pr-message`. If the platform cannot expand another command, follow the existing `draft-pr-message` prompt directly for the draft phase only. After its fenced message is produced, this command resumes and creates the pull request.

### Working tree handling

Use the branch's committed diff only. Do not stage, commit, or include unstaged files in the pull request title or body.

Treat unstaged overview, proposal, plan, alignment, validation, research, decision, handover, `RESEARCH-PLAN.md`, phase/task note, and files marked `working document, not for commit` as non-durable working documents. Leave them untouched and out of the pull request.

If uncommitted durable work appears required for the pull request, stop and ask the user to commit it first.

### Process

Run each command separately. Do not chain commands with `&&`, `;`, or `|`.

1. Inspect branch state with `git status --short --branch`, `git rev-parse --abbrev-ref HEAD`, `git log main..HEAD --oneline`, and `git diff main..HEAD --stat`.
2. Stop if the current branch is `main`, if there are no commits in `main..HEAD`, or if uncommitted durable work appears required for this pull request.
3. If staged files or unstaged files exist, leave them unchanged. Note that they are excluded because only committed branch changes are used.
4. Invoke or follow `draft-pr-message`. Preserve its fenced pull request message verbatim as the pull request source.
5. Strip only the Markdown fence lines. Use the first remaining line as the pull request title. Write the remaining body text unchanged to a temporary file.
6. Check whether the branch has an upstream with `git rev-parse --abbrev-ref --symbolic-full-name @{u}`. If no upstream exists, push with `git push -u origin HEAD`. If the branch is ahead of its upstream, push with `git push`. If the push requires force, deletion, tags, or a non-fast-forward update, stop.
7. Create the pull request with the dedicated GitHub CLI command: `gh pr create --base main --head <branch> --title <title> --body-file <temp-file>`. Never use raw `gh api`.
8. Report the pull request URL, title, and any uncommitted non-durable working documents left out.

### Output

```markdown
Pull request: <url>
Title: <title>
Excluded:
- <uncommitted non-durable working document left out, or none>
```