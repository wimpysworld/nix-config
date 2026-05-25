## Project Handover (Fresh Session)

Create a handover enabling a fresh engineer or agent - in a new session, with no inherited context - to continue without reverse-engineering decisions.

If the user supplied a focus, tailor the handover to that next-session goal rather than documenting the entire project.

For in-session briefings to a single specialist subagent, use `handover-fork` instead - it produces a shorter, packet-shaped briefing rather than a full handover document.

**Length:** 800-1200 words (typical), 1500-2000 (major systems)

**Markers:** ⚠️ WARNING (non-obvious behaviour), 📌 IMPORTANT (critical info)

### Required handling

- Save the handover outside the workspace in the OS temporary directory.
- Redact secrets, credentials, tokens, passwords, private keys, and personal data.
- Do not duplicate content already captured in PRDs, plans, ADRs, issues, commits, diffs, or other artefacts. Link to the path or URL instead and summarise only what the next agent must know.
- Include a **Suggested Skills** section naming skills the next agent should load and why.
- Prefer current conversation decisions, blockers, and working context over static project facts that are easy to rediscover.

### Sections

| Section           | Focus                                                         | Words   |
| ----------------- | ------------------------------------------------------------- | ------- |
| Context           | What, why, current state, architecture (one sentence)         | 100-150 |
| Key Decisions     | Problem → approach → rejected alternatives (non-obvious only) | 150-250 |
| Codebase          | Structure (2-3 levels), critical deps, env setup              | 200-350 |
| Technical         | Architecture/data flow only if text insufficient              | 150-300 |
| Development       | Essential commands, single most common gotcha                 | 100-200 |
| Known Limitations | Constraints discovered, workarounds (not hypotheticals)       | 100-200 |
| Remaining Work    | Outstanding items with approach and complexity (S/M/L)        | 150-300 |
| Suggested Skills  | Skills the next agent should invoke, with one-line reasons    | 50-100  |
| Quick Orientation | First-day setup (max 5 steps), starting point                 | 100-150 |

### Example

<example_section>
**Key Decisions**

📌 **Chose SQLite over PostgreSQL for local dev**

- Problem: CI slow due to Postgres container spin-up
- Approach: SQLite for tests, Postgres for staging/prod
- Trade-off: Must avoid Postgres-specific SQL in tested paths

⚠️ **Rate limiter uses sliding window, not fixed**

- Fixed window caused request bunching at boundaries
- Adds ~2ms latency but smoother distribution

**Suggested Skills**

- `code-security` - review the rate limiter and SQL paths before widening external access.
- `writing-clearly-and-concisely` - tighten the migration guide after implementation lands.
  </example_section>

### Constraints

- Skip sections that don't apply.
- Concrete examples over generic descriptions.
- Include failed approaches only if they inform current design.
- Exclude easily discoverable information.
- Keep references short and actionable: path or URL plus why it matters.
