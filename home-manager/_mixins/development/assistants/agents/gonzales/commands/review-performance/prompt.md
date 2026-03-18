## Performance Review

Analyse codebase for optimisation opportunities.

### Scope

Specify focus (or reviews entire codebase):

| Scope | Example |
|-------|---------|
| Hot path | "checkout process", "search endpoint" |
| Directory | `src/services/` |
| Layer | "database queries", "API responses", "rendering" |
| Symptom | "page load 5+ seconds", "memory grows over time" |

### Process

1. Identify performance-critical paths in scope
2. Analyse for bottlenecks (algorithmic, memory, I/O, CPU)
3. Reject any suggestion that requires restructuring or contradicts the project's existing architecture, design patterns, or intent - regardless of the performance gain
4. Apply impact rating from agent definition
5. Only include improvements that produce human-perceptible results: immediate UI responsiveness, or processing/response time savings a user would notice. Micro-optimisations are justified only when they compound across the primary execution path to produce a measurable aggregate improvement. Discard any suggestion with no demonstrable, observable effect.
6. Skip optimisations rated below 5 unless comprehensive review requested

### Example Invocations

<examples>
- "Review performance of the dashboard API endpoint"
- "Analyse database query patterns in src/repositories/"
- "Find optimisation opportunities in image processing pipeline"
- "Investigate why list pages slow down with 1000+ items"
</examples>
