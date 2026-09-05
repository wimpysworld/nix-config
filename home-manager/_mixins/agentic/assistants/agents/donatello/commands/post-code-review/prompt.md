## Post Code Review

Post one GitHub review to the target pull request. The comment body is the user's own text when the input carries some, and a `draft-code-review` draft when it does not.

This command mutates GitHub state and speaks as the user. Treat explicit human invocation of this command as consent for those actions. Never use raw `gh api`.

Command invocation: use the current provider's command prefix when invoking `draft-code-review`. Codex uses `$draft-code-review`; slash-command runtimes use `/draft-code-review`. Pass the exact selected report path as its argument. If the platform cannot expand another command or preserve that argument, follow the existing `draft-code-review` prompt directly for the draft phase only. After its fenced comment is produced, this command resumes and posts the review.

### Verdict and body

`$ARGUMENTS` is an optional verdict followed by optional comment text. When the first word is `approve` or `comment`, that word is the verdict and the rest is the comment text. Otherwise the verdict is `comment` and the whole of `$ARGUMENTS` is the comment text.

When `$ARGUMENTS` carries comment text, that text is the comment body, verbatim. Never rewrite, trim, or extend it. When it carries none, draft the body with `draft-code-review`.

There is no `changes` verdict: a `--request-changes` review blocks the pull request until the user dismisses it, so that call is the user's alone, made outside this command. There is no reject verdict: GitHub has no reject state, and closing a contribution is `gh pr close` and out of scope for this command.

`gh pr review --approve` is permitted under Fence. GitHub itself refuses approval of your own pull request, so an approve attempt on your own PR fails by design, not by a Fence rule.

### Process

Run each command separately. Do not chain commands with `&&`, `;`, or `|`.

1. Read `communication-rules` first unless its complete, current instructions are in this context. Apply it before starting. The rules never apply to user-supplied comment text, which stays verbatim
2. Resolve the target pull request. If the review targeted a local branch, worktree, or commit rather than a pull request, stop and say there is nothing to post to
3. When `$ARGUMENTS` carries comment text, take that text verbatim as the comment source and skip to step 7. Do not select a report or validate a review SHA
4. Load and follow the `review-report-path` skill for its path and safety rules. For this command only, replace its multi-report selection rule with these rules. Derive the project and pull request target, then search every `run-*` directory for that target. Consider only complete, non-empty regular files named `code-review-mine.md`, `code-review-colleague.md`, `code-review-community.md`, or `code-review-again.md`. Ignore run directories that contain no candidate report, including empty and fallback-only runs, and ignore `findings-*.md` and all unrelated files. Stop with a clear error if one run contains more than one candidate report. For each candidate run, extract the UTC timestamp in the exact `YYYYMMDDTHHMMSSZ` form from its `run-<timestamp>-*` directory name and validate it as a real UTC date and time. Stop with a clear error if a candidate run has a malformed timestamp. Select the sole candidate report with the greatest timestamp. Stop with a clear error if multiple candidate runs tie for the greatest timestamp. Never ask the user to choose a historical report. If no candidate report remains, list the available target directories and stop, saying that a review must run first. Never delete or overwrite a run directory or report
5. Invoke or follow `draft-code-review` with the exact selected report path as its argument. Preserve its fenced comment verbatim as the comment source
6. Compare the pull request's current head SHA against the SHA recorded when the selected review ran. If it has moved, stop and report that the contributor pushed during the review, so the findings may no longer apply. Do not post. This guard is internal; never write a SHA into the comment body
7. Show the exact comment body and the verdict, and confirm before posting
8. If the comment source came from `draft-code-review`, strip only the Markdown fence lines. Write the remaining body text unchanged to a temporary file
9. Post with the dedicated subcommand matching the verdict: `gh pr review <pr> --approve --body-file <temp-file>` or `gh pr review <pr> --comment --body-file <temp-file>`. Never use raw `gh api`
10. Report the pull request URL, the verdict posted, and the comment body

### Output

```markdown
Posted: <pr-url>
Verdict: <approve|comment>
Comment:
<verbatim comment body>
```
