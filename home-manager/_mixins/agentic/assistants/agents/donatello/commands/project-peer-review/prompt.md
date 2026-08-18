## Project Peer Review

Review this project as a seasoned developer of the associated language ecosystem. Give an honest verdict: **impressed**, **ambivalent**, or **disgusted** - and make the case for it.

Runs a full-project peer review. No arguments.

### Report Location

Before any worker starts, load and follow the `review-report-path` skill. Create a new run for the checkout target. Write the review as `peer-review.md` in the derived run directory, and use that directory for any fallback findings.

### Process

1. Load and follow the `communication-rules` skill before writing anything
2. Delegate to a wide fan-out of sub-agents, in parallel where possible. Split by subdirectory, recursing into every nested subdirectory, not only top-level ones. First-party code only: exclude git submodules. Each sub-agent runs this same peer review over its own directory; the parent aggregates the findings

   The user-invoked command is the sole orchestrator. Workers complete their assigned area and return directly. They never launch agents or invoke orchestrating commands.

3. Detect the primary language(s) and ecosystem from project manifests
4. Survey the codebase - structure, patterns, idioms, quality signals
5. Evaluate against what an experienced practitioner of this ecosystem would expect
6. Deliver a verdict with evidence
7. Use the report path derived before fan-out, write the review there, then report that path

### Verdict Criteria

| Verdict | Meaning |
|---------|---------|
| **Impressed** | Demonstrates real craft - idiomatic, well-structured, shows deep understanding of the ecosystem |
| **Ambivalent** | Mixed signals - some good work alongside avoidable sloppiness; competent but unremarkable |
| **Disgusted** | Actively harmful patterns - fights the language, ignores ecosystem conventions, creates maintenance burden |

### Output

- Open with the verdict and a one-sentence summary of why
- Support with specific examples (file paths, patterns, idioms) - not generic observations
- Note what impresses or disappoints most
- Close with what a peer would tell the author directly

### Constraints

- No diplomatic hedging - give the honest verdict a peer would give in a code review
- Cite specific code, not vague impressions
- **Impressed** with few or no complaints is a valid verdict. Do not inflate minor gripes into faults to justify a harsher grade.
- Judge the code as it stands. Do not flag speculative problems that depend on a future the code has not reached.
- Write the aggregated review to the derived path, then report that path
