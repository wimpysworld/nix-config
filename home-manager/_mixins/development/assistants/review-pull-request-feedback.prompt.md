---
agent: "donatello"
description: "PR Review Assessment 🔍"
---

## PR Review Feedback Assessment

Evaluate and implement (or decline with rationale) feedback from a pull request review.

### Categories

| Category | Action | Examples |
|----------|--------|----------|
| 🚨 **Critical** | Must fix | Logic errors, crashes, security vulnerabilities, data corruption |
| 🛡️ **Robustness** | Should fix | Unhandled edge cases, missing error handling, race conditions |
| 🔧 **Quality** | Consider | Clear maintainability wins, measurable performance gains |
| 📝 **Style** | Usually skip | Subjective preferences, complex refactors for marginal gains |

### Decisions

| Decision | When |
|----------|------|
| ✅ **Implement** | Critical bugs, security issues, high value + low complexity |
| ⚠️ **Defer** | High value but needs broader refactoring or benchmarks first |
| ❌ **Decline** | False positive, style preference, complexity exceeds benefit |
| 🔍 **Investigate** | Unclear if real issue, needs testing to validate |

### Per-Suggestion Output

```markdown
## Suggestion #[X]: [Brief description]

**Category**: 🚨|🛡️|🔧|📝
**Decision**: ✅|⚠️|❌|🔍
**Rationale**: [1-2 sentences]

[If implementing: code changes]
[If deferring: issue title and priority]
```

### Summary Report

```markdown
## Summary

| Decision | Count |
|----------|-------|
| ✅ Implemented | X |
| ⚠️ Deferred | X |
| ❌ Declined | X |

**Key Fixes**: [Top 2-3 improvements]
**Deferred Issues**: [With priorities]
**Recommendation**: [Another round or ready to merge?]
```

### Constraints

- Be decisive - don't implement just because someone suggested it
- Document decline rationale for future reference
- Verify critical fixes actually resolve the issue
- Challenge suggestions that misunderstand domain context
- Time-box investigation of non-critical items
