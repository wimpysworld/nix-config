## Make Commit

Draft the commit message with `draft-commit-message`, then create one Git commit from the intended durable work.

This command mutates Git by staging selected files and running `git commit`. It never pushes.

Use the supplied intent, paths, exclusions, validation evidence, and mutation authority. Optional `$ARGUMENTS` supplies context. On Codex, use the accompanying invocation text instead. Do not assume access to the parent conversation. OpenCode's native command binding supplies no parent-written packet, so require explicit context or clarify missing decisions.

Read current Git state before mutations. If intent, scope, or authority is missing or conflicts with Git evidence, stop before dependent writes. Ask the user, or return the missing decision to the parent. Do not infer intent or test results from the diff alone. Do not run concurrent index mutations.

Resolve `draft-commit-message` through the available skill catalogue, configured skill roots, or repository command source. Read its body directly and follow the draft phase here, without its generated launch wrapper. Supply the intent and current staged diff, and preserve its fenced message. This body also supports explicit coordinator inline reuse. Reading a body does not invoke its command or change the executor. Never launch another agent.

### Non-durable working documents

Treat unstaged overview, proposal, plan, alignment, validation, research, decision, handover, phase/task note, and files marked `working document, not for commit` as non-durable working documents. Do not stage them.

A document is durable only when it is intended project documentation, for example a README, docs page, ADR, changelog entry, or a user-named durable record.

### Process

Run each command separately. Do not chain commands with `&&`, `;`, or `|`.

1. Inspect the working tree with `git status --short --branch`.
2. Read `git diff --staged` before staging. Keep all already-staged content included. Do not reset, unstage, restore, or edit staged content. If staged content conflicts with the authorised scope or exclusions, stop and ask or return the conflict.
3. Identify unstaged durable changes that clearly belong in this commit. Leave unstaged non-durable working documents untouched. If a path is ambiguous, ask before staging it.
4. Stage extra durable paths only with explicit path-limited `git add -- <path> ...`. For partially staged files, inspect the unstaged diff before adding the path. Add it only when every remaining change belongs in this commit. Never use `git add .`, `git add -A`, `git add -u`, broad globs, or directory-wide staging unless every file in that directory was inspected and is intended for the commit.
5. Read `git diff --staged`. Stop if the index is empty or contains a non-durable working document. Run `git diff --staged --check` and stop if it fails.
6. Follow the `draft-commit-message` prompt with the known intent, conventions, status and staged diff. Do not repeat discovery for evidence already in context. Preserve its fenced commit message verbatim as the commit message source.
7. Strip only the Markdown fence lines. Write the remaining message text unchanged to a temporary file.
8. Run `git commit -F <temp-file>`.
9. Report the new short SHA and the commit message.

Use `git log`, diff statistics or a final status check only to resolve a specific gap or verify an unexpected result.

### Output

```markdown
Committed: <short-sha>
Message:
<verbatim fenced commit message from `draft-commit-message`>
Excluded:
- <unstaged non-durable working document left out, or none>
```
