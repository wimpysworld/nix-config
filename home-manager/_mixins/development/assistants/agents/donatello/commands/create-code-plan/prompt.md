## Create Code Implementation Plan

**Usage:** `/create-code-plan <output-file>`

The first argument is the file path to write the completed plan to (e.g. `plan.md`). Ask if not provided before proceeding.

Create implementation plan optimised for AI-assisted development.

### Task Structure

| Field | Content |
|-------|---------|
| ID | `<phase>.<number>` — Descriptive name |
| Dependencies | Tasks that must complete first, or "None" |
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

### Example

<example>
## Phase 1: Authentication Foundation

### 1.1 — Add JWT dependency and configuration
- **Dependencies**: None
- **Scope**: `package.json`, `src/config/auth.ts`
- **Success Criteria**: `npm test` passes, config loads from env
- **Complexity**: XS

### 1.2 — Implement token generation service
- **Dependencies**: 1.1
- **Scope**: `src/services/auth/token.ts`, `src/services/auth/token.test.ts`
- **Reuse**: `src/utils/crypto.ts` — existing `generateSecret()` for token signing
- **Success Criteria**: Unit tests pass for sign/verify/refresh
- **Complexity**: S
- **Flags**: 🔍 Review token expiry values

### 1.3 — Add auth middleware
- **Dependencies**: 1.2
- **Scope**: `src/middleware/auth.ts`, `src/middleware/auth.test.ts`
- **Reuse**: `src/middleware/validate.ts` — follow existing middleware pattern and error handling
- **Success Criteria**: Protected routes return 401 without valid token
- **Complexity**: M
- **Flags**: ⚠️ Affects all protected endpoints
</example>

### Constraints

- Each task must be independently testable
- Include test file in scope when adding/modifying functionality
- Flag tasks requiring decisions before implementation
- Note when scope may challenge context limits
- Write the completed plan to the output file specified in the command argument
