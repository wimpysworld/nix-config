---
agent: "rosey"
description: "Review Agent Prompts 🔬"
---

## Agent Prompt Review

Review instruction and/or command prompts against best practices. Apply Ineffective Patterns and High-Value Patterns from agent definition.

### Review Criteria

| Criterion | High Value | Low/No Value |
|-----------|------------|--------------|
| **Instructions** | Explicit, specific, actionable | Vague, generic, implicit |
| **Output format** | Detailed templates with structure | "Respond appropriately" |
| **Examples** | Few-shot for style/judgment tasks | None where judgment required |
| **Decision criteria** | Numeric thresholds, explicit conditions | "When appropriate", "if needed" |
| **Constraints** | Specific behaviours to avoid | Generic warnings |
| **Tool guidance** | When and how to use specific tools | "Use tools as needed" |
| **Persona** | Minimal (2-3 sentences max) | Lengthy character descriptions |

### Assessment Scale

| Rating | Meaning |
|--------|---------|
| ✅ **Strong** | Follows best practices, no significant issues |
| ⚠️ **Adequate** | Functional but has improvement opportunities |
| 🔧 **Needs Work** | Missing high-value patterns or contains ineffective patterns |
| ❌ **Restructure** | Fundamental issues requiring significant revision |

### Output Format

**Per-Prompt:**

```markdown
## [Prompt Name]

**Rating**: ✅|⚠️|🔧|❌

**Strengths:**
- [What follows best practices]

**Issues:**
| Issue | Criterion | Recommendation |
|-------|-----------|----------------|
| [Problem] | [Criterion] | [Fix] |

**Missing Patterns:** [High-value patterns absent]

**Token Efficiency:** [Current] → [After fixes]
```

**Summary (multiple prompts):**

```markdown
## Summary

| Prompt | Rating | Primary Issue |
|--------|--------|---------------|
| [name] | ✅|⚠️|🔧|❌ | [One-line summary] |

**Cross-Cutting Issues:** [Patterns in multiple prompts]

**Priority Fixes:** [Top 3 improvements]
```

### Constraints

- Cite vendor guidance when flagging issues (Anthropic, OpenAI, Google)
- Distinguish "ineffective" (remove) from "missing" (add)
- Provide concrete rewrites for fixable issues
- Flag command prompts that duplicate base agent constraints
- Do not penalise intentional brevity
- Instructions must be self-contained; commands should reference base prompt

