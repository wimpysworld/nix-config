## Make Commit

Draft the commit message with `draft-commit-message`, then create one Git commit from the intended durable work.

This command mutates Git by staging selected files and running `git commit`. It never pushes.

Run this command in the current context. Do not launch a sub-agent or a Task for any step; the current context holds the change intent that the commit message needs, and a delegation round trip loses it. For the draft phase, follow the `draft-commit-message` prompt directly in this context, ignoring any launch instruction in its composed body, and produce its fenced message here. One exception: when the staged diff is large and this session did not author it, delegate the whole command to the `garfield` agent instead.

### Non-durable working documents

Treat unstaged overview, proposal, plan, alignment, validation, research, decision, handover, phase/task note, and files marked `working document, not for commit` as non-durable working documents. Do not stage them.

A document is durable only when it is intended project documentation, for example a README, docs page, ADR, changelog entry, or a user-named durable record.

### Process

Run each command separately. Do not chain commands with `&&`, `;`, or `|`.

1. Inspect the working tree with `git status --short --branch`, `git diff --staged --name-status`, and `git diff --name-status`.
2. Keep all already-staged content included. Do not reset, unstage, restore, or edit staged content.
3. Identify unstaged durable changes that clearly belong in this commit. Leave unstaged non-durable working documents untouched. If a path is ambiguous, ask before staging it.
4. Stage extra durable paths only with explicit path-limited `git add -- <path> ...`. Never use `git add .`, `git add -A`, `git add -u`, broad globs, or directory-wide staging unless every file in that directory was inspected and is intended for the commit.
5. Verify the index with `git diff --staged --name-status` and `git diff --staged --check`. Stop if the index is empty or contains a non-durable working document.
6. Follow the `draft-commit-message` prompt. Preserve its fenced commit message verbatim as the commit message source.
7. Strip only the Markdown fence lines. Write the remaining message text unchanged to a temporary file.
8. Run `git commit -F <temp-file>`.
9. Report the new short SHA and the commit message.

### Output

```markdown
Committed: <short-sha>
Message:
<verbatim fenced commit message from `draft-commit-message`>
Excluded:
- <unstaged non-durable working document left out, or none>
```