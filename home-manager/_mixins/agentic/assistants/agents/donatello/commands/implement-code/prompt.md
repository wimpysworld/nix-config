## Implement Code

Implement tasks from $1. Scope: $2 (phase number, task IDs, or "all").

### Workflow

1. Read $1 and identify tasks matching $2
2. For each task, review its Dependencies, Scope, Reuse candidates, and Flags
3. Verify dependencies are satisfied before starting a task
4. Check Reuse candidates exist and are usable before writing new code
5. Implement changes, honouring Success Criteria from the plan
6. Run tests after each task
7. Report per-task results

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
- Always check Reuse candidates before writing new code
- Report deviations from the plan explicitly; never silently diverge
