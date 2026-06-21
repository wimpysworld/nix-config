## Test Review

Analyse codebase for high-value test additions.

Runs a full-project test-gap analysis. No arguments.

### Process

1. Delegate to a wide fan-out of sub-agents, in parallel where possible. Split by subdirectory, recursing into every nested subdirectory, not only top-level ones. First-party code only: exclude git submodules. Each sub-agent runs this same test-gap analysis over its own directory; the parent aggregates the findings
2. Analyse existing test patterns and coverage
3. Apply priority criteria from agent definition
4. Recommend tests ranked by bug-prevention value
5. Write the aggregated report to `TEST-REVIEW.md` in the project root
