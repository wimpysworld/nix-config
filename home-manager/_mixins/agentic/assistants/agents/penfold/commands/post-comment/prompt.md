## Post Comment

Draft the comment with the `draft-comment` skill, then post it to the target thread.

Target argument: $ARGUMENTS. This is the thread URL. For Slack it may instead be a channel ID, a channel name, or a person's user ID, which starts a new message rather than replying to one. If it is blank, ask which thread and wait.

This command mutates external state and speaks as the user. Treat explicit human invocation of this command as consent for those actions. Never use raw `gh api`.

Load `draft-comment` and apply it end-to-end for the draft phase. After it returns the fenced comment, resume this command and post it. Do not duplicate its drafting guidance here.

### Process

Run each command separately. Do not chain commands with `&&`, `;`, or `|`.

1. Resolve the target and name which surface it is: GitHub, Linear, or Slack. Load the `slack` skill when the surface is Slack. If a URL does not resolve to a real thread, stop and say so
2. Apply `draft-comment`. Preserve its fenced comment verbatim as the comment source
3. Show the exact comment body and the resolved target, and confirm before posting
4. Post with the dedicated tool for that surface:
   - GitHub issue or pull request: strip only the Markdown fence lines, write the remaining body text unchanged to a temporary file, then run `gh issue comment <url> --body-file <file>` or `gh pr comment <url> --body-file <file>`. Never use raw `gh api`
   - GitHub review comment: reply inside the thread with `gh-review-reply <review-comment-url> --body-file <file>`, using the same fence-stripped temporary file. Pass the review comment URL you were given, unchanged; the helper parses the owner, repository, pull request number, and comment id out of it. Both the `#discussion_r<id>` and `#r<id>` anchor forms work. Never use `gh pr comment` here; it posts at the top level, away from the question
   - Linear: the Linear MCP comment tool. Send real newlines in the body, never literal backslash-n
   - Slack: `slack-post <target> --body-file <file>`, using the same fence-stripped temporary file. Pass the target you were given, unchanged. The `slack` skill holds the target forms and the rest of the rules
5. Report the surface, the target URL, and the comment body

### Output

```markdown
Posted: <url>
Surface: <github|linear|slack>
Comment:
<verbatim fenced comment from `draft-comment`>
```
