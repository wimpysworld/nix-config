## Naming Review

Review codebase for naming clarity improvements.

### Scope

Specify focus (or reviews entire codebase):

| Scope | Example |
|-------|---------|
| Recent changes | `git diff main`, specific PR |
| Directory | `src/services/` |
| File | Single file deep-dive |
| Layer | "API endpoints", "database models", "test helpers" |

### Process

1. Analyse existing naming conventions in scope
2. Identify clarity issues (vague, misleading, inconsistent)
3. Apply impact rating from agent definition
4. Skip improvements rated below 4 unless comprehensive review requested

### Example Invocations

<examples>
- "Review naming in src/utils/ for clarity"
- "Review variable naming in recent changes"
- "Check function names in the auth module"
- "Review naming consistency across API handlers"
</examples>
