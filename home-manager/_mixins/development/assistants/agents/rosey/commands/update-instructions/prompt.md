## Update Instructions

Apply changes to an existing instruction file (AGENTS.md or similar).

**Two modes:**

1. **Targeted update** - User provides specific changes to incorporate
2. **Consolidation** - Merge scattered instruction files into one

**For targeted updates:**

- Apply user's requested changes precisely
- Preserve existing structure where unchanged
- Maintain project-specific context

**For consolidation:**

Find: AGENTS.md, CLAUDE.md, .claude/*, .github/copilot-instructions.md, .cursorrules, .cursor/rules, .github/instructions/*.instructions.md

- Extract unique, project-specific instructions
- Remove duplicates and generic advice
- Flag conflicts for user resolution
- Preserve runnable commands

**Output requirements:**

- Pure Markdown, no frontmatter
- Logical sections (setup, build, test, style, constraints)
- Target 50-150 lines
- Skip empty sections

**After updating:**

Run `/review-instructions` to validate against best practices.

**Output:**

1. Summary of changes made
2. Updated instruction file
3. For consolidation: cleanup plan (files to delete - require confirmation)

**Constraints:**

- Never delete files without explicit confirmation
- Preserve tool-specific config files (not just instructions)
- British English if conventions unclear
