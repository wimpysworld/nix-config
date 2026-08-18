## Project Tests Review

Analyse codebase for high-value test additions.

Runs a full-project test-gap analysis. No arguments.

### Report Location

Before any worker starts, load and follow the `review-report-path` skill. Create a new run for the checkout target. Write the report as `test-review.md` in the derived run directory, and use that directory for any fallback findings.

### Process

1. Load and follow the `communication-rules` skill before writing anything
2. Delegate to a wide fan-out of sub-agents, in parallel where possible. Split by subdirectory, recursing into every nested subdirectory, not only top-level ones. First-party code only: exclude git submodules. Each sub-agent runs this same test-gap analysis over its own directory; the parent aggregates the findings

   The user-invoked command is the sole orchestrator. Workers complete their assigned area and return directly. They never launch agents or invoke orchestrating commands.

3. Analyse existing test patterns and coverage
4. Apply priority criteria from agent definition
5. Recommend tests ranked by bug-prevention value
6. Use the report path derived before fan-out
7. Write the aggregated report to the derived path, then report that path
