## Project Tests Review

Analyse codebase for high-value test additions.

Runs a full-project test-gap analysis. No arguments.

### Report Location

Write the report to:

```
${TMPDIR:-/tmp}/agent-reviews/<project>/test-review.md
```

- `<project>` is the repository directory name, kebab-case.
- Create the directory if it does not exist.

The report is disposable. It lasts for one review only. Never commit it and never write it inside the repo.

Report the written path in your output so the user can find it.

### Process

1. Invoke `less` to reload the Communication Rules before writing anything. Codex uses `$less`; slash-command runtimes use `/less`. If the platform cannot expand a command, apply the Communication Rules directly
2. Delegate to a wide fan-out of sub-agents, in parallel where possible. Split by subdirectory, recursing into every nested subdirectory, not only top-level ones. First-party code only: exclude git submodules. Each sub-agent runs this same test-gap analysis over its own directory; the parent aggregates the findings
3. Analyse existing test patterns and coverage
4. Apply priority criteria from agent definition
5. Recommend tests ranked by bug-prevention value
6. Write the aggregated report to the derived path, then report that path
