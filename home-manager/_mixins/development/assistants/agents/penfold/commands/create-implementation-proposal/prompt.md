## Create Implementation Proposal

**Usage:** `/create-implementation-proposal <output-file>`

The first argument is the file path to write the completed proposal to (e.g. `proposal.md`). Ask if not provided before proceeding.

Define what to build, how to build it, and what to reuse - bridging research into a specification Donatello can plan against.

### Sections

| Section | Focus |
|---------|-------|
| Objective | What to build and why - one paragraph |
| Approach | Technical strategy, architectural decisions, key patterns |
| Reuse Audit | Existing code, utilities, and patterns to leverage - file paths and functions |
| Scope | Files to create or modify, with high-level intent per file |
| Acceptance Criteria | How to verify the implementation is complete and correct |
| Risks | Technical risks, unknowns, and dependencies that could block implementation |
| Out of Scope | What this proposal explicitly does not cover |

### Reuse Audit

Search the codebase before proposing new code. For each area of the implementation:

1. Grep for existing utilities, helpers, and similar patterns
2. Check for shared modules that already solve part of the problem
3. Note exact file paths and function names

| Status | Meaning |
|--------|---------|
| **Reuse** | Existing code covers this need - import and use directly |
| **Extend** | Existing code covers part of this need - extend rather than duplicate |
| **New** | No existing code applies - write from scratch |

### Example

<example_section>
## Reuse Audit

| Area | Status | Source | Notes |
|------|--------|--------|-------|
| Rate limiting | **Reuse** | `src/middleware/rateLimit.ts` | Already used on `/api/search` |
| Error responses | **Extend** | `src/utils/errors.ts` | Add `429` handler to existing factory |
| Upload validation | **New** | - | No file validation exists in codebase |
</example_section>

<example_section>
## Scope

| File | Intent |
|------|--------|
| `src/routes/upload.ts` | New endpoint using existing auth middleware and rate limiter |
| `src/utils/errors.ts` | Add `tooManyRequests()` to existing error factory |
| `src/validation/upload.ts` | New file: file type and size validation |
| `src/routes/upload.test.ts` | New file: endpoint tests including rate limit and validation |
</example_section>

### Markers

📌 KEY (critical decision), ⚠️ CAVEAT (limitation/uncertainty), → (recommendation)

### Constraints

- Search the codebase before proposing any new code; justify every "New" status in the reuse audit
- One proposal per feature - split large features into separate proposals
- Acceptance criteria must be testable, not subjective
- Skip sections that don't apply
- No implementation detail beyond what Donatello needs to plan tasks
- No hedging language ("perhaps", "might", "could potentially")
- Write the completed proposal to the output file specified in the command argument
