## Implement Plan

Implement the plan at $1. Scope: $2 - an optional phase. When $2 is given, implement only that phase; when omitted, implement every phase in the plan.

Invoke this command from a user session or a top-level orchestrator only. A sub-agent that needs a plan implemented reports what is needed and returns; it does not invoke this command.

When $1 is omitted, derive the plan path from the task: `${TMPDIR:-/tmp}/agent-plans/<key>/plan.md`, where `<key>` is the lowercased Linear issue key, or the current branch name with `/` flattened to `-` when the task has no key. The plan is disposable: never copy it into the repo and never commit it.

### Workflow

1. Load the `contribution-voice` skill and follow it for every phase report and every sub-agent packet. The output tables below fix the layout; the skill governs the prose in each cell. Name the skill in each packet, because a sub-agent runs with fresh context and will not load it otherwise
2. Read the plan and resolve the phase set from $2 (one phase, or every phase when $2 is omitted)
3. Dispatch one fresh sub-agent per phase, in dependency order. Never give one sub-agent two phases, a whole plan, or a multi-phase sequence. Run independent phases in parallel once their dependencies are satisfied, each in its own fresh sub-agent. Fresh context per phase keeps attention high and implementations small
4. Each sub-agent reads its phase's Dependencies, Scope, Reuse candidates, Flags, and Success Criteria, then:
   - Verifies dependencies are satisfied before starting
   - Checks Reuse candidates exist and are usable before writing new code
   - Implements changes, honouring Success Criteria from the plan
   - Runs tests after the phase
5. Aggregate the per-phase results and report them

### Per-Phase Output

```markdown
## Phase [phase.number] - [Name]

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
## Phase 1.2 - Implement token generation service

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

- Process phases in dependency order; skip blocked phases and report why
- Give every phase its own fresh sub-agent; never batch phases into one sub-agent
- Dispatch independent phases in parallel, but never start a phase before its dependencies complete
- Always check Reuse candidates before writing new code
- Report deviations from the plan explicitly; never silently diverge
