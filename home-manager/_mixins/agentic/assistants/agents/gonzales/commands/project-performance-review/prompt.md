## Project Performance Review

Analyse codebase for optimisation opportunities.

Runs a full-project performance analysis. No arguments.

### Report Location

Write the report to:

```
${TMPDIR:-/tmp}/agent-reviews/<project>/<target>/performance-review.md
```

Load the `review-report-path` skill and derive `<project>` and `<target>` from it. This command takes no argument, so the target is the checkout it runs in.

### Process

1. Load and follow the `communication-rules` skill before writing anything
2. Delegate to a wide fan-out of sub-agents, in parallel where possible. Split by subdirectory, recursing into every nested subdirectory, not only top-level ones. First-party code only: exclude git submodules. Each sub-agent runs this same performance analysis over its own directory; the parent aggregates the findings
3. Identify performance-critical paths
4. Analyse for bottlenecks (algorithmic, memory, I/O, CPU)
5. Reject any suggestion that requires restructuring or contradicts the project's existing architecture, design patterns, or intent - regardless of the performance gain
6. Apply impact rating from agent definition
7. Only include improvements that produce human-perceptible results: immediate UI responsiveness, or processing/response time savings a user would notice. Micro-optimisations are justified only when they compound across the primary execution path to produce a measurable aggregate improvement. Discard any suggestion with no demonstrable, observable effect.
8. Skip optimisations rated below 5
9. Load the `review-report-path` skill and derive the report path
10. Write the aggregated report to the derived path, then report that path
