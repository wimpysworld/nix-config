## Code Review

Review code for maintainability defects that can be fixed by removing, simplifying, or clarifying code.

### Scope

Specify focus (or reviews entire codebase):

| Scope | Example |
|-------|---------|
| Recent changes | `git diff main`, specific PR |
| Directory | `src/services/` |
| File | Single file deep-dive |
| Pattern | "error handling", "duplication in tests" |

### Process

1. Flag all dead code regardless of impact rating:
   unreachable blocks, unused exports/functions, commented-out code,
   obsolete feature flags, untested-and-uncalled code paths
2. Report dead code only when there is clear evidence it is unreachable,
   unused, obsolete, or superseded
3. Analyse remaining scope for simplification, duplication, and readability issues,
   in that order
4. Ignore formatting preferences, naming taste, and stylistic nits unless they
   materially harm comprehension
5. Rate each remaining finding by impact (1-10):
   4-5 local friction, 6-7 recurring maintenance cost, 8-10 structural drag
6. Output per-improvement format from agent definition
7. Skip findings rated below 4 unless the user explicitly asks for a comprehensive review

### Example Invocations

<examples>
- "Review code in src/auth/ for maintainability"
- "Review recent changes on this branch"
- "Review error handling patterns across the codebase"
- "Deep review of utils.ts"
</examples>
