## Create Code Implementation Plan

**Usage:** `/create-plan <output-file>`

The first argument (`$1`) is the file path to write the completed plan to (e.g. `plan.md`). Ask if not provided before proceeding.

Create implementation plan optimised for AI-assisted development.

### Task Structure

| Field | Content |
|-------|---------|
| ID | `<phase>.<number>` — Descriptive name |
| Assigned Agent | Planning-time agent chosen from the current available agent list using `delegate-task` routing |
| Assignment Reason | Why that agent owns the task or sub-phase |
| Dependencies | Tasks that must complete first, or "None" |
| Parallel | "Yes" when it can run with other unblocked tasks; otherwise "No" |
| Blocked By | Tasks, decisions, or external work blocking this task, or "None" |
| Scope | Files/functions to modify |
| Success Criteria | How to verify completion |
| Complexity | XS/S/M/L/XL |
| Reuse | Existing functions, utilities, or patterns to leverage |
| Flags | ⚠️ High-risk, 🔍 Needs review, 🧠 Context-intensive |

### Planning Principles

- **Atomic:** Each task completable in one session, independently testable, safely revertible
- **Chunked:** Group 3-5 related tasks; each chunk produces working code
- **Stateless:** Assume fresh AI instance per conversation
- **DRY:** Search for existing utilities and patterns before planning new code; reuse over rewrite
- **Cohesive:** Each task must not expand a module's responsibility beyond its existing concern; flag with 🔍 any task that concentrates unrelated responsibilities in one module or creates tight coupling between modules
- **Allocated:** Assign every task or sub-phase to an agent at planning time using `delegate-task` routing and the current dynamic agent list. Record the reason, avoid static defaults, and leave room for the executor to re-route if the available agents or implementation context differs.
- **Bounded:** Keep each delegated task small, with clear scope, dependencies, parallel eligibility, and blockers. Split broad, independent, or cross-cutting work so tasks can run in parallel where possible.

### Example

<example>
## Phase 1: Authentication Foundation

### 1.1 — Add JWT dependency and configuration
- **Assigned Agent**: Current agent selected by `delegate-task`
- **Assignment Reason**: Owns dependency and configuration changes in the current agent set
- **Dependencies**: None
- **Parallel**: Yes
- **Blocked By**: None
- **Scope**: `package.json`, `src/config/auth.ts`
- **Success Criteria**: `npm test` passes, config loads from env
- **Complexity**: XS

### 1.2 — Implement token generation service
- **Assigned Agent**: Current agent selected by `delegate-task`
- **Assignment Reason**: Owns service implementation in the current agent set
- **Dependencies**: 1.1
- **Parallel**: No
- **Blocked By**: 1.1
- **Scope**: `src/services/auth/token.ts`, `src/services/auth/token.test.ts`
- **Reuse**: `src/utils/crypto.ts` — existing `generateSecret()` for token signing
- **Success Criteria**: Unit tests pass for sign/verify/refresh
- **Complexity**: S
- **Flags**: 🔍 Review token expiry values

### 1.3 — Add auth middleware
- **Assigned Agent**: Current agent selected by `delegate-task`
- **Assignment Reason**: Owns middleware integration in the current agent set
- **Dependencies**: 1.2
- **Parallel**: No
- **Blocked By**: 1.2
- **Scope**: `src/middleware/auth.ts`, `src/middleware/auth.test.ts`
- **Reuse**: `src/middleware/validate.ts` — follow existing middleware pattern and error handling
- **Success Criteria**: Protected routes return 401 without valid token
- **Complexity**: M
- **Flags**: ⚠️ Affects all protected endpoints
</example>

### Constraints

- Each task must be independently testable
- Include test file in scope when adding/modifying functionality
- Assign each task or sub-phase to an agent chosen through `delegate-task`; do not embed a static agent list or fallback default
- Include the assignment reason, parallel eligibility, and blockers for each task
- Flag tasks requiring decisions before implementation
- Note when scope may challenge context limits
- Write the completed plan to `$1`
