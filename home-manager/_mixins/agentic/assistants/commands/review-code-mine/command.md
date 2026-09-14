## Review My Code

Review target: $ARGUMENTS. Accepts a pull request, a branch, a worktree, or a commit. Defaults to the current worktree when blank.

Load the `review-code` skill and follow its method. Pass `code-review-mine` as the `<review-name>` for the report filename.

### Context

These are the user's own changes, reviewed locally before they file a pull request. The point is to catch problems while they are still cheap to fix. This review is adversarial: assume the change is wrong and try to prove it.

### Lens

- **Goal conformance**: does the change deliver the stated outcome and acceptance criteria of its task or plan. `$ARGUMENTS` may carry a Linear issue key or URL, or a plan path, after the target; use it as extra context. If none is given, look for `${TMPDIR:-/tmp}/agent-plans/<branch>/plan.md`, where `<branch>` is the current branch name with `/` flattened to `-`, and say so if none is found
- **Completeness**: adjacent code, callers, and functionality that should have been updated with this change but were not
- **Regressions** in existing behaviour
- **Security** best practice
- **Tests and documentation** the change should have brought with it

### Severity Bar

Report anything that would make the change wrong, incomplete, or unsafe to ship. Skip preference-level polish. Be direct; there is no audience to manage.
