## Review Colleague Code

Review target: $ARGUMENTS. Accepts a pull request, a branch, a worktree, or a commit. Defaults to the current worktree when blank.

Load the `review-code` skill and follow its method. Pass `code-review-colleague` as the `<review-name>` for the report filename.

### Context

These are colleagues' pull requests at work. The review is posted publicly under the user's name, so their professional credibility rides on every finding. Precision matters more than coverage.

### Lens

Actual defects only:

- Correctness bugs and logic errors
- Security vulnerabilities
- Data loss
- Concurrency faults
- Error-handling gaps that bite in production
- Behavioural regressions

### Severity Bar

Report nothing that is not a defect.

- No style, naming, formatting, or comment wording.
- No optional suggestions. No "consider" or "you might want to". No nits.
- An empty finding list is a good outcome. Report it plainly; never pad it.
- If the only thing to say is that the change looks correct, say exactly that.

Donatello's instincts as an implementer will surface improvements. Those are out of scope here. Discard them; do not list them as non-blocking.
