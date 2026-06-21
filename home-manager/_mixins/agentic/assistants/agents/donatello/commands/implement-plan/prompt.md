## Implement Plan

Implement $1. Scope: $2 - an optional phase. When $2 is given, implement only that phase; when omitted, implement the whole plan.

### Workflow

1. Read $1 and resolve the task set from $2 (one phase, or the whole plan when $2 is omitted)
2. Dispatch one fresh sub-agent per task, in dependency order - independent tasks within a phase may run in parallel; a task whose dependencies are unmet waits for them
3. Each sub-agent reads its plan task's Dependencies, Scope, Reuse candidates, Flags, and Success Criteria, then:
   - Verifies dependencies are satisfied before starting
   - Checks Reuse candidates exist and are usable before writing new code
   - Implements changes, honouring Success Criteria from the plan
   - Runs tests after the task
4. Aggregate the per-task results and report them

### Per-Task Output

```markdown
## Task [phase.number] — [Name]

**Reuse:** [What was reused from plan's Reuse field, or "None specified"]

**Changes:**
| File | Change |
|------|--------|
| `path/to/file` | Description |

**Verification:**
| Success Criterion | Result |
|--------------------|--------|
| [From plan] | ✅ Pass / ❌ Fail |

**Deviations:** [From plan, if any - omit if none]
**Flags addressed:** [⚠️/🔍/🧠 from plan, if any - omit if none]
```

### Example

<example>
## Task 1.2 — Implement token generation service

**Reuse:** `src/utils/crypto.ts` - used existing `generateSecret()` for token signing

**Changes:**
| File | Change |
|------|--------|
| `src/services/auth/token.ts` | Created with sign/verify/refresh using existing crypto utils |
| `src/services/auth/token.test.ts` | Unit tests for all three functions |

**Verification:**
| Success Criterion | Result |
|--------------------|--------|
| Unit tests pass for sign/verify/refresh | ✅ Pass |

**Flags addressed:** 🔍 Token expiry set to 24h based on pattern in session.ts
</example>

### Constraints

- Process tasks in dependency order; skip blocked tasks and report why
- Dispatch independent tasks in parallel, but never start a task before its dependencies complete
- Always check Reuse candidates before writing new code
- Report deviations from the plan explicitly; never silently diverge
