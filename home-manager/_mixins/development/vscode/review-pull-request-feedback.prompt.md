---
agent: 'dilbert'
description: 'GitHub Copilot PR Review Assessment & Implementation'
---
I need you to systematically evaluate and implement (or explicitly decline with rationale) the feedback from GitHub Copilot's pull request review. Your goal is to improve code quality whilst maintaining development velocity and avoiding over-engineering.

### Assessment Framework

For each piece of Copilot feedback, follow this structured evaluation:

#### 1. **Categorise by Impact Level**

Classify each suggestion into one of these categories:

**🚨 Critical Bugs** (MUST FIX)
- Logic errors breaking core functionality
- Runtime crashes, data corruption, or memory leaks
- Security vulnerabilities (injection, auth bypass, data exposure)
- Undefined behaviour that will cause production failures

**🛡️ Robustness Issues** (SHOULD FIX)
- Unhandled edge cases that could cause failures
- Missing error handling or recovery
- Race conditions or concurrency issues
- Input validation gaps
- Resource management problems (unclosed handles, memory cleanup)

**🔧 Code Quality** (CONSIDER FIXING)
- Clear maintainability improvements
- Performance optimizations with measurable benefit
- Clarity improvements that reduce cognitive load
- DRY violations with simple fixes
- Documentation gaps for complex logic

**📝 Style/Architecture** (USUALLY SKIP)
- Subjective formatting preferences
- Complex refactoring for marginal gains
- Premature optimizations without metrics
- Alternative patterns with no clear advantage
- Comment style or verbosity preferences

#### 2. **Apply Impact Assessment Matrix**

For each issue, answer these four questions:

1. **Severity**: What breaks if we ignore this? (None/Minor/Major/Critical)
2. **Probability**: How likely is this to occur? (Rare/Occasional/Common/Certain)
3. **Complexity**: How difficult is the fix? (Trivial/Simple/Moderate/Complex)
4. **Value**: What's the benefit/cost ratio? (Negative/Low/Medium/High)

Score as: `[Severity × Probability] / Complexity = Priority Score`

#### 3. **Implementation Decision Rules**

Based on your assessment, take one of these actions:

**✅ IMPLEMENT** if:
- Critical bug (any severity × certain probability)
- High-value fix with low complexity
- Security issue of any kind
- Data integrity risk
- Clear bug with simple fix

**⚠️ DEFER** (create issue for later) if:
- High value but high complexity
- Good idea but not critical path
- Requires broader refactoring
- Performance optimization needing benchmarks first

**❌ DECLINE** (with documented reason) if:
- False positive (misunderstands intent)
- Style preference with no objective benefit
- Would break existing functionality
- Conflicts with project conventions
- Complexity exceeds benefit

**🔍 INVESTIGATE** if:
- Unclear whether it's a real issue
- Need to understand broader impact
- Requires testing to validate

### Response Format

For each Copilot suggestion, provide:

```markdown
## Suggestion #[X]: [Brief description]

**Category**: 🚨|🛡️|🔧|📝 [Category name]

**Assessment**:
- Severity: [None/Minor/Major/Critical] - [Why]
- Probability: [Rare/Occasional/Common/Certain] - [Context]
- Complexity: [Trivial/Simple/Moderate/Complex] - [What's involved]
- Value: [Negative/Low/Medium/High] - [Benefit explanation]

**Decision**: ✅ IMPLEMENT | ⚠️ DEFER | ❌ DECLINE | 🔍 INVESTIGATE

**Rationale**: [1-2 sentences explaining the decision]

**Implementation** (if implementing):
```[language]
// Code changes here
```

**Issue Created** (if deferring):
- Title: [Issue title]
- Priority: [P0/P1/P2/P3]
- Milestone: [When to address]
```

### Context Considerations

Factor in these project-specific elements:

1. **Project Phase**:
   - Prototype → Functionality over polish
   - Production → Reliability and robustness critical
   - Maintenance → Code quality improvements valuable

2. **Technical Debt Budget**:
   - How much complexity can we afford now?
   - What's our refactoring capacity?

3. **False Positive Patterns**:
   - Is Copilot misunderstanding our architecture?
   - Are we using unconventional but intentional patterns?
   - Is this a domain-specific practice it doesn't recognise?

4. **Diminishing Returns Check**:
   - Are we seeing mostly style suggestions now?
   - Have critical issues been addressed?
   - Is continued iteration worthwhile?

### Summary Report

After processing all feedback, provide:

```markdown
## Implementation Summary

**Statistics**:
- Total suggestions: [X]
- Implemented: [X] (Critical: [X], Robustness: [X], Quality: [X])
- Deferred: [X] (Issues created: [list issue numbers])
- Declined: [X] (False positives: [X], Low value: [X])

**Key Improvements Made**:
1. [Most important fix implemented]
2. [Second most important]
3. [etc.]

**Technical Debt Created**:
- [Issues deferred for later]

**Patterns Noticed**:
- [Any recurring themes in the feedback]
- [Quality of suggestions trend]

**Recommendation**:
[Should we run another review round or move forward?]
```

### Special Instructions

- **Be decisive**: Don't implement suggestions just because Copilot made them
- **Document thoroughly**: Future engineers need to understand why we declined certain suggestions
- **Preserve intent**: Ensure fixes don't break intentional behaviour
- **Test critical fixes**: Verify that bug fixes actually resolve the issues
- **Challenge assumptions**: Copilot doesn't always understand domain context
- **Time-box effort**: Don't spend more than [X] hours on non-critical improvements

Remember: The goal is code that works reliably, not code that satisfies every possible linter. Focus on real problems that affect real users or developers.
