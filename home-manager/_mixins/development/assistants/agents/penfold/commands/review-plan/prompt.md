## Review Plan

Conduct a meticulous review of $1.

### Process

1. Read the entire plan document before beginning review
2. Research every feature, configuration option, and integration point for accuracy and correctness
3. Use tools extensively - web search, documentation, code context. Training data is inadequate for verification
4. Seek genuine shortcomings and issues, not hypotheticals. Do not manufacture findings or feel obliged to create them

### Output: `REVIEW.md`

Produce `REVIEW.md` capturing findings with cited sources and recommendations.

#### Sections

| Section | Focus |
|---------|-------|
| Summary | Scope of review, overall assessment - one paragraph |
| Findings | Issues grouped by theme, each with evidence and source citations |
| Recommendations | One clear, decisive recommendation per finding - no hedging |
| Verdict | Overall readiness assessment: ready, ready with caveats, or needs revision |

#### Per-Finding Format

<example_output>
### [Theme]: [Issue title]

**Issue**: Description of the genuine shortcoming found.

**Evidence**: What the plan states vs. what research reveals, with source citations.

**Recommendation**: One clear action. No hedging, no alternatives.
</example_output>

### Constraints

- Do not conjure recommendations out of thin air
- Every finding must be backed by research with cited sources
- One recommendation per finding - decisive, not hedged
- No filler findings to pad the review
- Skip sections that have no findings
