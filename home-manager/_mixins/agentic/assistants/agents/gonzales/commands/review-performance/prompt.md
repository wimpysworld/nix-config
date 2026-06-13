## Performance Review

Analyse codebase for optimisation opportunities.

Runs a full-project performance analysis. No arguments.

### Process

1. Dispatch one sub-agent per subdirectory, recursing into every nested subdirectory, not just top-level ones. First-party code only: exclude git submodules. Each sub-agent runs this same performance analysis over its own directory; the parent aggregates the findings
2. Identify performance-critical paths
3. Analyse for bottlenecks (algorithmic, memory, I/O, CPU)
4. Reject any suggestion that requires restructuring or contradicts the project's existing architecture, design patterns, or intent - regardless of the performance gain
5. Apply impact rating from agent definition
6. Only include improvements that produce human-perceptible results: immediate UI responsiveness, or processing/response time savings a user would notice. Micro-optimisations are justified only when they compound across the primary execution path to produce a measurable aggregate improvement. Discard any suggestion with no demonstrable, observable effect.
7. Skip optimisations rated below 5
8. Write the aggregated report to `PERF-REVIEW.md` in the project root
