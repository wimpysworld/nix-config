## Create Documentation Plan

Review documentation and information architecture for the project.

### Priority Criteria

| Priority | User Impact |
|----------|-------------|
| Critical | Users cannot complete core tasks |
| High | Users waste significant time or make mistakes |
| Medium | Users experience friction but can work around |
| Low | Nice-to-have improvement |

### Output

**1. Current State**
- What exists and where
- Missing docs (critical paths undocumented)
- Stale content (contradicts code or describes removed features)

**2. Prioritised Improvements**

Per improvement:
- **Issue**: What's wrong or missing
- **Impact**: Critical/High/Medium/Low
- **Recommendation**: Specific action
- **Effort**: XS/S/M/L/XL

**3. Structure Changes** (if needed)
- Proposed reorganisation with rationale
- Migration path

### Example

<example>
**Issue**: No quickstart—README jumps to API reference
**Impact**: Critical—new users cannot start without reading source
**Recommendation**: Add "Getting Started" with 5-minute working example
**Effort**: M

**Issue**: CLI flags in README don't match `--help` output
**Impact**: High—users get errors following docs
**Recommendation**: Regenerate from `--help`, add CI check
**Effort**: S
</example>

### Constraints

- Focus on gaps that hurt users, not nice-to-have
- Prioritise getting-started over comprehensive reference
- Flag stale docs as high priority (wrong docs worse than none)
