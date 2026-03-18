## Update Instructions

Review and update instruction files (AGENTS.md or similar) in one pass: assess against best practices, then apply improvements.

**Two modes:**

1. **Targeted update** - user provides specific changes to incorporate
2. **Consolidation** - merge scattered instruction files into one

**For consolidation, find:**

AGENTS.md, CLAUDE.md, .claude/*, .github/copilot-instructions.md, .cursorrules, .cursor/rules, .github/instructions/*.instructions.md

- Extract unique, project-specific instructions; remove duplicates and generic advice
- Flag conflicts for user resolution; preserve runnable commands

**Review criteria (assess before updating):**

| Criterion | High Value | Low/No Value |
|-----------|------------|--------------|
| **Instructions** | Explicit, specific, actionable | Vague, generic, implicit |
| **Output format** | Detailed templates with structure | "Respond appropriately" |
| **Examples** | Few-shot for style/judgment tasks | None where judgment required |
| **Decision criteria** | Numeric thresholds, explicit conditions | "When appropriate", "if needed" |
| **Constraints** | Specific behaviours to avoid | Generic warnings |
| **Tool guidance** | When and how to use specific tools | "Use tools as needed" |
| **Persona** | Minimal (2-3 sentences max) | Lengthy character descriptions |

**Assessment scale:**

| Rating | Meaning |
|--------|---------|
| ✅ **Strong** | Follows best practices, no significant issues |
| ⚠️ **Adequate** | Functional but has improvement opportunities |
| 🔧 **Needs Work** | Missing high-value patterns or contains ineffective patterns |
| ❌ **Restructure** | Fundamental issues requiring significant revision |

**Output:**

```markdown
## [File Name]
**Rating**: ✅|⚠️|🔧|❌
**Issues:** [table: issue / criterion / recommendation]
**Changes made:** [bullet list]
```

Followed by the updated instruction file. For consolidation: cleanup plan (files to delete - require confirmation).

**Output requirements for instruction files:**

- Pure Markdown, no frontmatter
- Logical sections (setup, build, test, style, constraints)
- Target 50-150 lines; skip empty sections

**Constraints:**

- Cite vendor guidance when flagging issues (Anthropic, OpenAI, Google)
- Distinguish "ineffective" (remove) from "missing" (add); provide concrete rewrites
- Flag command prompts that duplicate base agent constraints
- Do not penalise intentional brevity
- Never delete files without explicit confirmation
- Preserve tool-specific config files (not just instructions)
- British English if conventions unclear
