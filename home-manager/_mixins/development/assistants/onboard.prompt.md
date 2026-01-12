---
agent: "donatello"
description: "Onboard 📥"
---

## Project Onboarding

Review attached handover document.

**Output:**

1. **Summary** (3-5 sentences): What we're building, current state, your understanding of the approach
2. **Clarifying questions** on:
   - Ambiguous decisions or missing rationale
   - Unclear implementation steps
   - Unfamiliar dependencies or tools
   - Priority or sequencing concerns
3. **Concerns** about proposed approaches
4. **Recommended first task** with rationale

### Example Questions

<example>
- Key Decisions §2: SQLite for tests—avoid transactions in test code, or is there a compatibility layer?
- Remaining Work §7: "Refactor auth middleware" (L)—blocked by rate limiter, or independent?
- Codebase: No mention of `services/legacy/`—deprecated or still in use?
</example>

Clarify now rather than discovering gaps mid-implementation.
