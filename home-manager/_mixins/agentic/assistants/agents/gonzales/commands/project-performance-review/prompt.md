## Project Performance Review

Analyse codebase for optimisation opportunities.

Runs a full-project performance analysis. No arguments.

### Report Location

Before any worker starts, load and follow the `review-report-path` skill. Create a new run for the checkout target. Write the report as `performance-review.md` in the derived run directory, and use that directory for any fallback findings.

### Process

1. Load and follow the `communication-rules` skill before writing anything
2. Delegate to a wide fan-out of sub-agents, in parallel where possible. Split by subdirectory, recursing into every nested subdirectory, not only top-level ones. First-party code only: exclude git submodules. Each sub-agent runs this same performance analysis over its own directory; the parent aggregates the findings

   The user-invoked command is the sole orchestrator. Workers complete their assigned area and return directly. They never launch agents or invoke orchestrating commands.

3. Identify performance-critical paths
4. Analyse for bottlenecks (algorithmic, memory, I/O, CPU)
5. Reject any suggestion that requires restructuring or contradicts the project's existing architecture, design patterns, or intent - regardless of the performance gain
6. Apply impact rating from agent definition
7. Only include improvements that produce human-perceptible results: immediate UI responsiveness, or processing/response time savings a user would notice. Micro-optimisations are justified only when they compound across the primary execution path to produce a measurable aggregate improvement. Discard any suggestion with no demonstrable, observable effect.
8. Skip optimisations rated below 5
9. Use the report path derived before fan-out
10. Write the aggregated report to the derived path, then report that path
