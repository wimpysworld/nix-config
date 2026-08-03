## Post Issue

Draft the issue with the `draft-issue` skill, then create it on the target repository.

Target argument: $ARGUMENTS. This is the target repository. If it is blank, ask for the repository and wait.

This command mutates GitHub state and speaks as the user. Treat explicit human invocation of this command as consent for those actions. Never use raw `gh api`.

Load `draft-issue` and apply it end-to-end for the draft phase. After it returns the fenced issue, resume this command and create it. Do not duplicate its drafting guidance here.

`gh issue create` is permitted under Fence, while `gh issue delete`, `lock`, `unlock`, `transfer`, `pin`, and `unpin` are denied, so this command creates and never moderates.

### Process

Run each command separately. Do not chain commands with `&&`, `;`, or `|`.

1. Resolve the target repository. If it does not resolve, stop and say so
2. Apply `draft-issue`. Preserve its fenced output verbatim as the issue source
3. Strip only the Markdown fence lines. Use the first remaining line as the title. Write the remaining body text unchanged to a temporary file
4. Show the exact title and body, and confirm before posting
5. Create with `gh issue create --repo <repo> --title <title> --body-file <temp-file>`. Never use raw `gh api`
6. Report the issue URL, the title, and the body

### Output

```markdown
Posted: <issue-url>
Title: <title>
Body:
<verbatim fenced body from `draft-issue`>
```
