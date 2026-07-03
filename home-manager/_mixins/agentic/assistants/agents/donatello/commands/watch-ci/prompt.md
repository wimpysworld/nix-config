## Watch CI

Watch CI on GitHub PR `$ARGUMENTS` until every check finishes, then fix the failures the PR caused. Ask for the PR URL if not provided.

### 1. Delegate the watch

Delegate a sub-agent to poll the PR checks until they all complete. Use dedicated `gh` subcommands: `gh pr checks` for status, `gh run view` and `gh run view --log-failed` for failing runs. Raw `gh api` is denied; use `gh-api-safe` for raw API reads. Never mutate GitHub: no comments, approvals, re-runs, or merges. Record the head commit SHA watched.

### 2. Triage failures

Sort each failed check into one of two groups:

- **Caused by this PR**: the failure traces to code the PR changed. In scope to fix.
- **Unrelated**: flaky infrastructure, a failure that also fails on the base branch, or a check untouched by the diff. Out of scope. Report it, do not fix it.

Read the diff and the failing logs together to decide. State the evidence for each call.

### 3. Delegate the fixes

Delegate each in-scope failure to its own sub-agent, in parallel where possible, one error per agent. Each sub-agent's packet must instruct it to:

- Read the failing log and the surrounding code in the working tree.
- Make the smallest change that fixes the error without breaking other checks.
- Verify the fix locally where practical.
- Return the files changed and why.

### 4. Draft the commit message

After the fixes land, run `/draft-commit-message` to draft the commit message for the staged review.

### Output

- List each failed check, its group (caused by this PR or unrelated), and the evidence.
- For in-scope failures, list the fix and the files touched.
- For unrelated failures, name them and stop; do not fix them.
- End with the drafted commit message in a fenced block.

### Constraints

- British English throughout. Short sentences, active voice, no filler.
- Edits land in the working tree only. Stage nothing. Commit nothing. The user reviews and commits.
- Never mutate GitHub: no comments, approvals, re-runs, or merges.
