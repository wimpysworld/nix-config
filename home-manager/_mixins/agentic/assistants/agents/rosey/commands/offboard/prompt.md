## Project Handover Document

Create handover enabling next engineer to continue without reverse-engineering decisions.

**Length:** 800-1200 words (typical), 1500-2000 (major systems)

**Markers:** ⚠️ WARNING (non-obvious behaviour), 📌 IMPORTANT (critical info)

### Sections

| Section | Focus | Words |
|---------|-------|-------|
| Context | What, why, current state, architecture (one sentence) | 100-150 |
| Key Decisions | Problem → approach → rejected alternatives (non-obvious only) | 150-250 |
| Codebase | Structure (2-3 levels), critical deps, env setup | 200-350 |
| Technical | Architecture/data flow only if text insufficient | 150-300 |
| Development | Essential commands, single most common gotcha | 100-200 |
| Known Limitations | Constraints discovered, workarounds (not hypotheticals) | 100-200 |
| Remaining Work | Outstanding items with approach and complexity (S/M/L) | 150-300 |
| Quick Orientation | First-day setup (max 5 steps), starting point | 100-150 |

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
</example_section>

### Constraints

- Skip sections that don't apply
- Concrete examples over generic descriptions
- Include failed approaches only if they inform current design
- Exclude easily discoverable information
