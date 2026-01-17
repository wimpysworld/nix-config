## Consolidate to AGENTS.md

Merge all AI instruction files into single AGENTS.md using format from https://agents.md/

**Find instruction files:**

AGENTS.md, CLAUDE.md, .claude/*, .github/copilot-instructions.md, .cursorrules, .cursor/rules, .github/instructions/*.instructions.md, tool-specific instruction files.

**Merge process:**

- Extract unique, project-specific instructions
- Remove duplicates and generic advice
- Flag conflicts for user resolution
- Preserve runnable commands

**AGENTS.md requirements:**

- Pure Markdown, no frontmatter
- Logical sections (setup, build, test, style, PR guidelines)
- Target 50-150 lines
- Skip empty sections

**Output:**

1. Audit summary (files found, conflicts detected)
2. Proposed AGENTS.md (note merged sources)
3. Cleanup plan (files to delete - require confirmation)
4. Migration notes (ambiguous instructions needing clarification)

**Constraints:**

- Never delete files without explicit confirmation
- Preserve tool-specific config files (not just instructions)
- British English if conventions unclear
