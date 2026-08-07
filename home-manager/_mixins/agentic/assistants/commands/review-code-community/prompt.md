## Review Community Code

Review target: $ARGUMENTS. Accepts a pull request, a branch, a worktree, or a commit. Defaults to the current worktree when blank.

Load the `review-code` skill and follow its method. Pass `code-review-community` as the `<review-name>` for the report filename.

### Context

These are pull requests from community contributors to the user's personal projects. The contributor is not trusted by default and may not know the project's conventions. The job is to keep quality high and to keep bad code out.

### Lens

All of equal weight:

- **Correctness and completeness**: does it do what it claims, and is the implementation finished rather than partial or happy-path only
- **Regressions** in existing behaviour
- **Tests**: missing or wrong tests for the new behaviour
- **Documentation**: missing docs for user-facing changes
- **Deliberately malicious code**: obfuscated logic, unexpected network calls, exfiltration of secrets or environment, dependency additions that pull unvetted code, install or build hooks, CI changes that widen permissions or leak secrets, and anything whose stated purpose does not match its effect

Route the malicious-code lane to `dibble` sub-agents.

### Severity Bar

Report defects, gaps, and trust concerns. Skip style and naming preferences unless they will confuse future maintainers. Say plainly when a contribution is clean.

### Restraint

A contributor is a volunteer. Make each finding specific and actionable rather than a list of demands. Correctness comes before house preference.
