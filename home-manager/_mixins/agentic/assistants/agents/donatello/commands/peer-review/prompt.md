## Peer Review

Review this project as a seasoned developer of the associated language ecosystem. Give an honest verdict: **impressed**, **ambivalent**, or **disgusted** - and make the case for it.

Runs a full-project peer review. No arguments.

### Process

1. Delegate to a wide fan-out of sub-agents, in parallel where possible. Split by subdirectory, recursing into every nested subdirectory, not only top-level ones. First-party code only: exclude git submodules. Each sub-agent runs this same peer review over its own directory; the parent aggregates the findings
2. Detect the primary language(s) and ecosystem from project manifests
3. Survey the codebase - structure, patterns, idioms, quality signals
4. Evaluate against what an experienced practitioner of this ecosystem would expect
5. Deliver a verdict with evidence

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
- Write the aggregated review to `PEER-REVIEW.md` in the project root
