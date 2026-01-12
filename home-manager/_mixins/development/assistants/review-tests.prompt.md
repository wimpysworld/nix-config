---
agent: "brain"
description: "Review Tests 🧪"
---

## Test Review

Analyse codebase for high-value test additions.

### Scope

Specify focus (or reviews entire codebase):

| Scope | Example |
|-------|---------|
| Recent changes | `git diff main`, specific PR |
| Directory | `src/services/billing/` |
| Risk area | "payment processing", "auth flows" |
| Gap type | "error handling", "edge cases" |

### Process

1. Analyse existing test patterns and coverage
2. Apply priority criteria from agent definition
3. Recommend tests ranked by bug-prevention value

### Example Invocations

<examples>
- "Review test coverage for src/services/billing/"
- "What tests should we add for the recent auth changes?"
- "Identify missing edge case tests in API handlers"
- "Review error handling coverage across the codebase"
</examples>
