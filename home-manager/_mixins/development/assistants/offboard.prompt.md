---
agent: "rosey"
description: "Handover 📤"
---

## Project Handover Document

Create a handover document enabling the next engineer to continue without reverse-engineering our decisions.

### Document Guidelines

- Target **800-1200 words** for typical features, **1500-2000 words** for major systems
- Skip or minimise sections that don't apply
- Prefer concrete examples over generic descriptions
- ⚠️ Mark gotchas explicitly; 📌 for critical information

### Required Sections

**1. Context** (100-150 words)

- What we're building and why
- Current state: completed vs remaining work
- Single sentence on architectural approach

**2. Key Decisions** (150-250 words)

- Document decisions with context: problem → chosen approach → alternatives considered and rejected
- Focus on non-obvious choices that would be costly to rediscover

**3. Working Codebase** (200-350 words)

- Repository structure at 2-3 levels deep, skip obvious directories
- Critical dependencies only (purpose + version constraint)
- One-liner for environment setup

**4. Technical Essentials** (150-300 words)

- Architecture diagram only if text alone is insufficient
- Data flow through the new/changed components only
- Core logic explained in 2-3 sentences maximum

**5. Development** (100-200 words)

- Essential commands only (setup, test, run)
- Single most common gotcha with workaround
- Skip documentation that's easily discoverable

**6. Known Limitations** (100-200 words)

- Technical constraints discovered
- Workarounds and their trade-offs
- Skip hypothetical issues

**7. Remaining Work** (150-300 words)

- List only truly outstanding items
- For each: description + recommended approach + complexity estimate (S/M/L)
- Skip obvious follow-ups

**8. Quick Orientation** (100-150 words)

- First-day environment setup (max 5 steps)
- Recommended starting point with rationale
- Skip generic project information

### Formatting

- ⚠️ WARNING for non-obvious behaviour
- 📌 IMPORTANT for critical information
- Include failed approaches only if they inform the current design
