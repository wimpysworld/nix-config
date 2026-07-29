## Project Tests Review

Analyse codebase for high-value test additions.

Runs a full-project test-gap analysis. No arguments.

### Report Location

Write the report to:

```
${TMPDIR:-/tmp}/agent-reviews/<project>/<target>/test-review.md
```

Load the `review-report-path` skill and derive `<project>` and `<target>` from it. This command takes no argument, so the target is the checkout it runs in.

### Process

1. Invoke `less` to reload the Communication Rules before writing anything. Codex uses `$less`; slash-command runtimes use `/less`. If the platform cannot expand a command, apply the Communication Rules directly
2. Delegate to a wide fan-out of sub-agents, in parallel where possible. Split by subdirectory, recursing into every nested subdirectory, not only top-level ones. First-party code only: exclude git submodules. Each sub-agent runs this same test-gap analysis over its own directory; the parent aggregates the findings
3. Analyse existing test patterns and coverage
4. Apply priority criteria from agent definition
5. Recommend tests ranked by bug-prevention value
6. Load the `review-report-path` skill and derive the report path
7. Write the aggregated report to the derived path, then report that path
