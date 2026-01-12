---
agent: "penry"
description: "Review Code 🔍"
---

## Code Review

Review codebase for maintainability improvements.

### Scope

Specify focus (or reviews entire codebase):

| Scope | Example |
|-------|---------|
| Recent changes | `git diff main`, specific PR |
| Directory | `src/services/` |
| File | Single file deep-dive |
| Pattern | "error handling", "duplication in tests" |

### Process

1. Analyse scope for simplification, duplication, dead code, readability issues
2. Rate each finding by impact (1-10)
3. Output per-improvement format from agent definition
4. Skip findings rated below 4 unless comprehensive review requested

### Example Invocations

<examples>
- "Review code in src/auth/ for maintainability"
- "Review recent changes on this branch"
- "Review error handling patterns across the codebase"
- "Deep review of utils.ts"
</examples>
