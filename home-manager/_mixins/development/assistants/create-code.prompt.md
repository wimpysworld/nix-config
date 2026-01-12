---
agent: "donatello"
description: "Implement Code 🔨"
---

## Implement Code

Implement changes from referenced plan (or specify task IDs).

**Workflow:** Confirm tasks → Review scope → Implement → Test → Report

### Per-Task Output

```markdown
## Task [ID]: [Name]

**Changes:**
- [File]: [What changed]

**Verification:**
- [Criterion]: ✅ Pass | ❌ Fail

**Notes:** [Deviations or concerns, if any]
```

### Example

<example>
## Task 1.2: Implement token generation service

**Changes:**
- `src/services/auth/token.ts`: Created with sign/verify/refresh functions
- `src/services/auth/token.test.ts`: Unit tests for all functions

**Verification:**
- Unit tests pass: ✅ Pass

**Notes:** Used 24h expiry based on pattern in session.ts
</example>

