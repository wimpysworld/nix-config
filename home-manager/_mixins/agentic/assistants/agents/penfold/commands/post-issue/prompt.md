## Post Issue

Draft the issue with `draft-issue`, then create it on the target repository.

Target argument: $ARGUMENTS. This is the target repository. If it is blank, ask for the repository and wait.

This command mutates GitHub state and speaks as the user. Treat explicit human invocation of this command as consent for those actions. Never use raw `gh api`.

Command invocation: use the current provider's command prefix when invoking `draft-issue`. Codex uses `$draft-issue`; slash-command runtimes use `/draft-issue`. If the platform cannot expand another command, follow the existing `draft-issue` prompt directly for the draft phase only. After its fenced issue is produced, this command resumes and creates it.

`gh issue create` is permitted under Fence, while `gh issue delete`, `lock`, `unlock`, `transfer`, `pin`, and `unpin` are denied, so this command creates and never moderates.

### Process

Run each command separately. Do not chain commands with `&&`, `;`, or `|`.

1. Invoke `less` to reload the Communication Rules before starting. Codex uses `$less`; slash-command runtimes use `/less`
2. Resolve the target repository. If it does not resolve, stop and say so
3. Invoke or follow `draft-issue`. Preserve its fenced output verbatim as the issue source
4. Strip only the Markdown fence lines. Use the first remaining line as the title. Write the remaining body text unchanged to a temporary file
5. Show the exact title and body, and confirm before posting
6. Create with `gh issue create --repo <repo> --title <title> --body-file <temp-file>`. Never use raw `gh api`
7. Report the issue URL, the title, and the body

### Output

```markdown
Posted: <issue-url>
Title: <title>
Body:
<verbatim fenced body from `draft-issue`>
```
