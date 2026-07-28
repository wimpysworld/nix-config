## Project Performance Review

Analyse codebase for optimisation opportunities.

Runs a full-project performance analysis. No arguments.

### Report Location

Write the report to:

```
${TMPDIR:-/tmp}/agent-reviews/<project>/performance-review.md
```

- `<project>` is the repository directory name, kebab-case.
- Create the directory if it does not exist.

The report is disposable. It lasts for one review only. Never commit it and never write it inside the repo.

Report the written path in your output so the user can find it.

### Process

1. Invoke `less` to reload the Communication Rules before writing anything. Codex uses `$less`; slash-command runtimes use `/less`. If the platform cannot expand a command, apply the Communication Rules directly
2. Delegate to a wide fan-out of sub-agents, in parallel where possible. Split by subdirectory, recursing into every nested subdirectory, not only top-level ones. First-party code only: exclude git submodules. Each sub-agent runs this same performance analysis over its own directory; the parent aggregates the findings
3. Identify performance-critical paths
4. Analyse for bottlenecks (algorithmic, memory, I/O, CPU)
5. Reject any suggestion that requires restructuring or contradicts the project's existing architecture, design patterns, or intent - regardless of the performance gain
6. Apply impact rating from agent definition
7. Only include improvements that produce human-perceptible results: immediate UI responsiveness, or processing/response time savings a user would notice. Micro-optimisations are justified only when they compound across the primary execution path to produce a measurable aggregate improvement. Discard any suggestion with no demonstrable, observable effect.
8. Skip optimisations rated below 5
9. Write the aggregated report to the derived path, then report that path
