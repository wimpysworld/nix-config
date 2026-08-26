## Create Code Implementation Plan

**Usage:** `/create-plan [task]`

The argument is the task being planned: a Linear issue key and title, or a local task title. Ask if not provided before proceeding.

Create implementation plan optimised for AI-assisted development.

### Plan Location

Write the plan to:

```
${TMPDIR:-/tmp}/agent-plans/<key>/plan.md
```

- `<key>` is the Linear issue key, lowercased (for example `ww-65`). When the task has no issue key, use the current branch name with `/` flattened to `-`.
- Create the directory if it does not exist.

The path is derived from the task so a fresh sub-agent can find the plan without being handed it.

The plan is disposable. It lasts for one task's implementation only. Never commit it, never write it inside the repo, and never treat it as a durable record. The task is the durable record.

Report the plan path in your output so the caller can pass it on.

### Phase Structure

| Field | Content |
|-------|---------|
| ID | `<phase>.<number>` - Descriptive name |
| Assigned Agent | Planning-time agent chosen from the current available agent list using `delegate-task` routing |
| Assignment Reason | Why that agent owns the phase or sub-phase |
| Dependencies | Phases that must complete first, or "None" |
| Parallel | "Yes" when it can run with other unblocked phases; otherwise "No" |
| Blocked By | Phases, decisions, or external work blocking this phase, or "None" |
| Scope | Files/functions to modify |
| Success Criteria | How to verify completion |
| Reuse | Existing functions, utilities, or patterns to build on |
| Flags | ⚠️ High-risk, 🔍 Needs review, 🧠 Context-intensive |

### Planning Principles

- **Atomic:** Each phase completable in one session, independently testable, safely revertible
- **Chunked:** Group 3-5 related phases; each chunk produces working code
- **Stateless:** Assume fresh AI instance per conversation
- **DRY:** Search for existing utilities and patterns before planning new code; reuse over rewrite
- **Cohesive:** Each phase must not expand a module's responsibility beyond its existing concern; flag with 🔍 any phase that concentrates unrelated responsibilities in one module or creates tight coupling between modules
- **Allocated:** Assign every phase or sub-phase to an agent at planning time using `delegate-task` routing and the current dynamic agent list. Record the reason, avoid static defaults, and leave room for the executor to re-route if the available agents or implementation context differs.
- **Bounded:** Keep each delegated phase small, with clear scope, dependencies, parallel eligibility, and blockers. Split broad, independent, or cross-cutting work so phases can run in parallel where possible.

### Example

<example>
## Phase 1: Authentication Foundation

### 1.1 - Add JWT dependency and configuration
- **Assigned Agent**: Current agent selected by `delegate-task`
- **Assignment Reason**: Owns dependency and configuration changes in the current agent set
- **Dependencies**: None
- **Parallel**: Yes
- **Blocked By**: None
- **Scope**: `package.json`, `src/config/auth.ts`
- **Success Criteria**: `npm test` passes, config loads from env

### 1.2 - Implement token generation service
- **Assigned Agent**: Current agent selected by `delegate-task`
- **Assignment Reason**: Owns service implementation in the current agent set
- **Dependencies**: 1.1
- **Parallel**: No
- **Blocked By**: 1.1
- **Scope**: `src/services/auth/token.ts`, `src/services/auth/token.test.ts`
- **Reuse**: `src/utils/crypto.ts` - existing `generateSecret()` for token signing
- **Success Criteria**: Unit tests pass for sign/verify/refresh
- **Flags**: 🔍 Review token expiry values

### 1.3 - Add auth middleware
- **Assigned Agent**: Current agent selected by `delegate-task`
- **Assignment Reason**: Owns middleware integration in the current agent set
- **Dependencies**: 1.2
- **Parallel**: No
- **Blocked By**: 1.2
- **Scope**: `src/middleware/auth.ts`, `src/middleware/auth.test.ts`
- **Reuse**: `src/middleware/validate.ts` - follow existing middleware pattern and error handling
- **Success Criteria**: Protected routes return 401 without valid token
- **Flags**: ⚠️ Affects all protected endpoints
</example>

### Constraints

- Each phase must be independently testable
- Include test file in scope when adding/modifying functionality
- Assign each phase or sub-phase to an agent chosen through `delegate-task`; do not embed a static agent list or fallback default
- Include the assignment reason, parallel eligibility, and blockers for each phase
- Flag phases requiring decisions before implementation
- Note when scope may challenge context limits
- Write the completed plan to the derived path, then report that path
