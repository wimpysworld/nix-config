## Post Comment

Draft the comment with `draft-comment`, then post it to the target thread.

Target argument: $ARGUMENTS. This is the thread URL. If it is blank, ask which thread and wait.

This command mutates external state and speaks as the user. Treat explicit human invocation of this command as consent for those actions. Never use raw `gh api`.

Command invocation: use the current provider's command prefix when invoking `draft-comment`. Codex uses `$draft-comment`; slash-command runtimes use `/draft-comment`. If the platform cannot expand another command, follow the existing `draft-comment` prompt directly for the draft phase only. After its fenced comment is produced, this command resumes and posts it.

### Process

Run each command separately. Do not chain commands with `&&`, `;`, or `|`.

1. Invoke `less-is-more` to reload the Communication Rules before starting. Codex uses `$less-is-more`; slash-command runtimes use `/less-is-more`
2. Resolve the target from the URL and name which surface it is: GitHub, Linear, or Slack. If the URL does not resolve to a real thread, stop and say so
3. Invoke or follow `draft-comment`. Preserve its fenced comment verbatim as the comment source
4. Show the exact comment body and the resolved target, and confirm before posting
5. Post with the dedicated tool for that surface:
   - GitHub issue or pull request: strip only the Markdown fence lines, write the remaining body text unchanged to a temporary file, then run `gh issue comment <url> --body-file <file>` or `gh pr comment <url> --body-file <file>`. Never use raw `gh api`
   - GitHub review comment: reply inside the thread with `gh-review-reply <owner> <repo> <pr-number> <comment-id> --body-file <file>`, using the same fence-stripped temporary file. The comment id is the number in the `#discussion_r<id>` URL. Owner and repo are literal names, not `{owner}` placeholders. Never use `gh pr comment` here; it posts at the top level, away from the question
   - Linear: the Linear MCP comment tool. Send real newlines in the body, never literal backslash-n
   - Slack: the Slack MCP message tool, replying in thread when the URL names a thread
6. Report the surface, the target URL, and the comment body

### Output

```markdown
Posted: <url>
Surface: <github|linear|slack>
Comment:
<verbatim fenced comment from `draft-comment`>
```
