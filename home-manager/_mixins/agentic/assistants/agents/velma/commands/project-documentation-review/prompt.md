## Project Documentation Review

Review documentation and information architecture for the project.

Runs a full-project documentation audit. No arguments.

### Report Location

Write the report to:

```
${TMPDIR:-/tmp}/agent-reviews/<project>/<target>/documentation-review.md
```

Load the `review-report-path` skill and derive `<project>` and `<target>` from it. This command takes no argument, so the target is the checkout it runs in.

### Priority Criteria

| Priority | User Impact |
|----------|-------------|
| Critical | Users cannot complete core tasks |
| High | Users waste significant time or make mistakes |
| Medium | Users experience friction but can work around |
| Low | Nice-to-have improvement |

### Process

1. Delegate to a wide fan-out of sub-agents, in parallel where possible. Split by subdirectory, recursing into every nested subdirectory, not only top-level ones. First-party code only: exclude git submodules. Each sub-agent runs this same documentation audit over its own directory; the parent aggregates the findings
2. Inventory the documentation that exists, where it lives, and which paths it covers
3. Compare each document against the code it describes to find missing and stale content
4. Rank every gap against the priority criteria above
5. Load the `review-report-path` skill and derive the report path
6. Write the aggregated report to the derived path, then report that path

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
- **Effort**: T-shirt size from the `sizing` skill

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
