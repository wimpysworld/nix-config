## Post Code Review

Draft the review comment with `draft-code-review`, then post it to the target pull request as one GitHub review.

This command mutates GitHub state and speaks as the user. Treat explicit human invocation of this command as consent for those actions. Never use raw `gh api`.

Command invocation: use the current provider's command prefix when invoking `draft-code-review`. Codex uses `$draft-code-review`; slash-command runtimes use `/draft-code-review`. If the platform cannot expand another command, follow the existing `draft-code-review` prompt directly for the draft phase only. After its fenced comment is produced, this command resumes and posts the review.

### Verdict

`$ARGUMENTS` is one of `approve`, `changes`, or `comment`. If it is blank, derive the verdict from the drafted comment and state which one you chose before asking to proceed. If it is anything else, stop.

There is no reject verdict: GitHub has no reject state, `--request-changes` is the block, and closing a contribution is `gh pr close` and out of scope for this command.

`gh pr review --approve` is permitted under Fence. GitHub itself refuses approval of your own pull request, so an approve attempt on your own PR fails by design, not by a Fence rule.

### Process

Run each command separately. Do not chain commands with `&&`, `;`, or `|`.

1. Invoke `less` to reload the Communication Rules before starting. Codex uses `$less`; slash-command runtimes use `/less`
2. Resolve the target pull request. If the review targeted a local branch, worktree, or commit rather than a pull request, stop and say there is nothing to post to
3. Invoke or follow `draft-code-review`. Preserve its fenced comment verbatim as the comment source
4. Compare the pull request's current head SHA against the SHA recorded when the review ran. If it has moved, stop and report that the contributor pushed during the review, so the findings may no longer apply. Do not post. This guard is internal; never write a SHA into the comment body
5. Show the exact comment body and the verdict, and confirm before posting
6. Strip only the Markdown fence lines. Write the remaining body text unchanged to a temporary file
7. Post with the dedicated subcommand matching the verdict: `gh pr review <pr> --approve --body-file <temp-file>`, `gh pr review <pr> --request-changes --body-file <temp-file>`, or `gh pr review <pr> --comment --body-file <temp-file>`. Never use raw `gh api`
8. Report the pull request URL, the verdict posted, and the comment body

### Output

```markdown
Posted: <pr-url>
Verdict: <approve|changes|comment>
Comment:
<verbatim fenced comment from `draft-code-review`>
```
